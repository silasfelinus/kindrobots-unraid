# ProxySQL admin access on Alexandria

ProxySQL has two distinct classes of users that are easy to confuse:

- **frontend MySQL users** are the application/database users registered in ProxySQL for traffic on port 6033;
- **ProxySQL admin users** authenticate to the private admin module on port 6032.

The admin interface is intentionally not published. Use it from Alexandria through `docker exec`.

## Connect

```bash
docker exec -it proxysql mariadb -h 127.0.0.1 -P 6032 -u admin -p
```

## If the admin password has been forgotten

The bootstrap credential is stored locally in the mounted ProxySQL configuration, not in this repository:

```text
/mnt/user/appdata/proxysql/proxysql.cnf
```

Confirm the configured admin username/password pair locally with:

```bash
grep -n 'admin_credentials' /mnt/user/appdata/proxysql/proxysql.cnf
```

The output contains the real admin password. **Do not paste it into chat, GitHub, logs, tickets, or documentation.** Use it only at the local password prompt.

The relevant configuration shape is:

```text
admin_variables=
{
  admin_credentials="admin:<secret>"
  mysql_ifaces="0.0.0.0:6032"
}
```

If the username is not `admin`, use the username shown by `admin_credentials` in the `docker exec` command.

## Useful production-health snapshot

After connecting:

```sql
SELECT * FROM stats_mysql_connection_pool;
SELECT * FROM stats_mysql_global;
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 20;
SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 20;
SELECT * FROM monitor.mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 20;
```

Never expose port 6032 publicly merely to make administration easier. The local `docker exec` path is the intended administration boundary.
