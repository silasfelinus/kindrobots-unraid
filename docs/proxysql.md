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

Do not place real credentials in this repository.

## Recommended Docker network

Create or reuse a custom Docker network shared by MariaDB and ProxySQL. Use stable container aliases, such as `mariadb` and `proxysql`, rather than a public hostname for backend traffic.

Only ProxySQL port `6033` should be application-facing. Port `6032` is administrative and must stay on the trusted LAN.

## Host directories

```text
/mnt/user/appdata/proxysql/
├── proxysql.cnf
└── data/
```

Create them before installing the template:

```bash
mkdir -p /mnt/user/appdata/proxysql/data
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
    active=1
    transaction_persistent=1
    max_connections=200
  }
)
```

This file is intentionally conservative. It accepts up to 500 frontend connections but caps the first MariaDB backend at 40 connections. Tune only after measuring actual memory, latency, and query concurrency.

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
4. Start the container.
5. Do not forward port `6032` through the router.

## Verify

From the Unraid terminal or another trusted host:

```bash
mysql -h UNRAID_HOST -P 6033 -u CHANGE_ME_APP_USER -p CHANGE_ME_DATABASE
```

Then connect to the admin interface from the LAN:

```bash
mysql -h UNRAID_HOST -P 6032 -u admin -p
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

## Switching Kind Robots

Do not change Vercel until a direct ProxySQL read and write both succeed.

After verification, point `DATABASE_URL` at the ProxySQL public endpoint and port `6033`. Keep the application-side pool limit at two connections per Vercel runtime instance.

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

## Publication status

This template is a deployable draft, not yet Community Applications ready. Before publication we will pin a tested image version, perform a clean-install test, validate upgrade behavior, confirm the icon format, and add backup and recovery instructions.
