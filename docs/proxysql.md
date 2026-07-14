# ProxySQL on Unraid

This is the first infrastructure app in the Kind Robots Unraid catalog.

## Purpose

ProxySQL sits between Kind Robots and MariaDB. It accepts many frontend client sessions while keeping a controlled number of backend MariaDB connections. It also provides monitoring, query statistics, hostgroups, and a foundation for future failover.

## Before installation

Collect:

- MariaDB container hostname or Docker-network alias
- MariaDB port, normally `3306`
- application database name
- application database username and password
- new ProxySQL monitor username and password
- new ProxySQL admin password
- the hostname or IP address applications use to reach ProxySQL

Do not place real credentials in this repository.

## Recommended Docker network

Create or reuse a custom Docker network shared by MariaDB and ProxySQL. Use stable container aliases, such as `mariadb` and `proxysql`, rather than a public hostname for backend traffic.

Only ProxySQL port `6033` is application-facing inside the container. Do not publish container port `6032`; administer ProxySQL with `docker exec` from Unraid.

A host-port mapping can retain an existing external database port. For example:

```text
Unraid host :5544 -> ProxySQL container :6033 -> MariaDB container :3306
```

## Host directories

```text
/mnt/user/appdata/proxysql/
├── proxysql.cnf
├── data/
└── pki/
```

Create them before installing the template:

```bash
mkdir -p /mnt/user/appdata/proxysql/{data,pki}
```

## Bootstrap configuration

Create `/mnt/user/appdata/proxysql/proxysql.cnf` and replace every `CHANGE_ME` value:

```text
datadir="/var/lib/proxysql"

admin_variables=
{
  admin_credentials="admin:CHANGE_ME_ADMIN_PASSWORD"
  mysql_ifaces="0.0.0.0:6032"
}

mysql_variables=
{
  threads=4
  max_connections=500
  default_query_delay=0
  default_query_timeout=36000000
  poll_timeout=2000
  interfaces="0.0.0.0:6033"
  default_schema="CHANGE_ME_DATABASE"
  stacksize=1048576
  connect_timeout_server=5000
  monitor_username="proxysql_monitor"
  monitor_password="CHANGE_ME_MONITOR_PASSWORD"
  monitor_history=600000
  monitor_connect_interval=2000
  monitor_ping_interval=2000
  monitor_read_only_interval=1500
  ping_interval_server_msec=120000
  ping_timeout_server=500
  commands_stats=true
  sessions_sort=true
  connect_retries_on_failure=3
}

mysql_servers =
(
  {
    address="mariadb"
    port=3306
    hostgroup=10
    max_connections=40
  }
)

mysql_users =
(
  {
    username="CHANGE_ME_APP_USER"
    password="CHANGE_ME_APP_PASSWORD"
    default_hostgroup=10
    default_schema="CHANGE_ME_DATABASE"
    active=1
    transaction_persistent=1
    max_connections=200
  }
)
```

This file is intentionally conservative. It accepts up to 500 frontend connections but caps the first MariaDB backend at 40 connections. Tune only after measuring actual memory, latency, and query concurrency.

ProxySQL persists active configuration in `/var/lib/proxysql/proxysql.db`. After the first start, changing `proxysql.cnf` alone may not change runtime values. Use the admin interface and `LOAD`/`SAVE` commands, or deliberately rebuild the ProxySQL database during initial setup.

## MariaDB monitor account

Run in MariaDB using an administrative account:

```sql
CREATE USER 'proxysql_monitor'@'%' IDENTIFIED BY 'CHANGE_ME_MONITOR_PASSWORD';
GRANT USAGE, REPLICATION CLIENT ON *.* TO 'proxysql_monitor'@'%';
FLUSH PRIVILEGES;
```

The application user must exist in both MariaDB and ProxySQL with matching credentials.

## Install

1. Add the XML template from `templates/proxysql.xml` to Unraid.
2. Verify the config and data paths.
3. Attach ProxySQL to the same custom Docker network as MariaDB.
4. Map the chosen Unraid host port to container port `6033`.
5. Do not publish or forward port `6032`.
6. Start the container.

## Verify routing

Connect through the published host port from another container or trusted host:

```bash
mariadb \
  --disable-ssl-verify-server-cert \
  -h UNRAID_HOST \
  -P EXTERNAL_PORT \
  -u CHANGE_ME_APP_USER \
  -p \
  CHANGE_ME_DATABASE
```

Then verify the path:

```sql
SELECT DATABASE(), @@hostname, CURRENT_USER(), NOW();
```

Administer ProxySQL without publishing port `6032`:

```bash
docker exec -it proxysql \
  mariadb -h 127.0.0.1 -P 6032 -u admin -p
```

Useful checks:

```sql
SELECT * FROM runtime_mysql_servers;
SELECT * FROM runtime_mysql_users;
SELECT * FROM stats_mysql_connection_pool;
SELECT * FROM stats_mysql_global;
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 20;
SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 20;
SELECT * FROM monitor.mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 20;
```

## Verified frontend TLS

ProxySQL can generate frontend certificates automatically, but the generated server certificate may not identify the hostname or IP address used by the application. Create a private CA and a server certificate whose Subject Alternative Name matches the actual endpoint.

The example below uses `100.89.251.10` as the application-facing address and also permits Docker-network testing through the `proxysql` hostname. Replace the address before running it when your endpoint differs.

```bash
DATA_DIR=/mnt/user/appdata/proxysql/data
PKI_DIR=/mnt/user/appdata/proxysql/pki
BACKUP_DIR="$DATA_DIR/tls-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$DATA_DIR" "$PKI_DIR" "$BACKUP_DIR"
cp -a "$DATA_DIR"/proxysql-*.pem "$BACKUP_DIR"/ 2>/dev/null || true
umask 077

openssl genrsa -out "$PKI_DIR/proxysql-ca-key.pem" 4096
openssl req -x509 -new -nodes \
  -key "$PKI_DIR/proxysql-ca-key.pem" \
  -sha256 -days 3650 \
  -out "$DATA_DIR/proxysql-ca.pem" \
  -subj "/CN=Kind Robots ProxySQL CA"

cat > "$PKI_DIR/proxysql-server.cnf" <<'EOF'
[req]
distinguished_name = dn
prompt = no
req_extensions = v3_req

[dn]
CN = 100.89.251.10

[v3_req]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = 100.89.251.10
DNS.1 = proxysql
DNS.2 = alexandria
EOF

openssl genrsa -out "$DATA_DIR/proxysql-key.pem" 2048
openssl req -new \
  -key "$DATA_DIR/proxysql-key.pem" \
  -out "$PKI_DIR/proxysql.csr" \
  -config "$PKI_DIR/proxysql-server.cnf"

openssl x509 -req \
  -in "$PKI_DIR/proxysql.csr" \
  -CA "$DATA_DIR/proxysql-ca.pem" \
  -CAkey "$PKI_DIR/proxysql-ca-key.pem" \
  -CAcreateserial \
  -out "$DATA_DIR/proxysql-cert.pem" \
  -days 825 -sha256 \
  -extensions v3_req \
  -extfile "$PKI_DIR/proxysql-server.cnf"

chmod 600 "$DATA_DIR/proxysql-key.pem" "$PKI_DIR/proxysql-ca-key.pem"
chmod 644 "$DATA_DIR/proxysql-ca.pem" "$DATA_DIR/proxysql-cert.pem"

docker restart proxysql
```

Verify the certificate:

```bash
openssl x509 \
  -in /mnt/user/appdata/proxysql/data/proxysql-cert.pem \
  -noout -subject -issuer -dates -ext subjectAltName
```

Test verified TLS from inside the ProxySQL container:

```bash
docker exec -it proxysql \
  mariadb \
  --ssl-ca=/var/lib/proxysql/proxysql-ca.pem \
  --ssl-verify-server-cert \
  -h proxysql \
  -P 6033 \
  -u CHANGE_ME_APP_USER \
  -p \
  CHANGE_ME_DATABASE
```

Never send either private key to Vercel. Only the public CA certificate, `proxysql-ca.pem`, is needed by the application.

## Switching Kind Robots

Do not change Vercel until a direct ProxySQL read and write both succeed.

Keep `DATABASE_URL` pointed at the application-facing endpoint and external port. The external port does not need to equal ProxySQL's container port `6033`.

Kind Robots supports either of these environment variables:

- `DATABASE_SSL_CA_BASE64`: base64-encoded contents of `proxysql-ca.pem`
- `DATABASE_SSL_CA`: raw PEM text or PEM text with escaped newlines

Create the portable base64 value on Unraid:

```bash
base64 /mnt/user/appdata/proxysql/data/proxysql-ca.pem | tr -d '\n'
```

Add that output to Vercel as `DATABASE_SSL_CA_BASE64`, then redeploy. The application will enable TLS and validate both the CA chain and the endpoint identity.

After the TLS-enabled deployment is confirmed, require SSL for the application user through the ProxySQL admin interface:

```sql
UPDATE mysql_users
SET use_ssl = 1
WHERE username = 'CHANGE_ME_APP_USER';

LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
```

Keep the application-side pool limit at two connections per Vercel runtime instance.

## Persistence warning

ProxySQL stores runtime state in its SQLite database under `/var/lib/proxysql`. Configuration changes made through the admin interface should normally be loaded to runtime and saved to disk:

```sql
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
```

Some variables, including the frontend interfaces setting, require a ProxySQL restart after saving to disk.

## Publication status

This template is a deployable draft, not yet Community Applications ready. Before publication we will pin a tested image version, perform a clean-install test, validate upgrade behavior, confirm the icon format, and add backup and recovery instructions.
