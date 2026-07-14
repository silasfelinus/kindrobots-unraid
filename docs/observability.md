# ProxySQL pooling observability

Tooling for the `observe-pooling` task in `projects/roadmap.yaml`
(`database-resilience` phase): measure frontend sessions, backend
connections, latency, and failures before tuning rate limits or
`max_connections`.

## Script

`scripts/observe-pooling.sh` reads the ProxySQL admin interface
(`127.0.0.1:6032` inside the container, never published) and reports:

- `stats_mysql_connection_pool` — per-backend `ConnUsed`, `ConnFree`,
  `ConnOK`, `ConnERR`, `Queries`, `Latency_us`. This is the direct signal for
  whether the backend hostgroup's `max_connections=40` cap (see
  `docs/proxysql.md`) is being saturated.
- `stats_mysql_global` — frontend/backend connection counters
  (`Client_Connections_*`, `Server_Connections_*`) and query volume
  (`Questions`, `Slow_queries`).

Run it directly on the Unraid host, or anywhere with `docker exec` access to
the `proxysql` container:

```bash
export PROXYSQL_ADMIN_PASSWORD='...'   # never commit this
./scripts/observe-pooling.sh
```

## Trend logging

For sustained observation (recommended before deciding on `rate-limits` and
`backup-restore` tuning), append snapshots to a CSV instead of printing a
one-off report:

```bash
./scripts/observe-pooling.sh --csv /mnt/user/appdata/proxysql/pooling-log.csv
```

Schedule it from the Unraid User Scripts plugin or cron, e.g. every 5
minutes:

```cron
*/5 * * * * PROXYSQL_ADMIN_PASSWORD='...' /path/to/kindrobots-unraid/scripts/observe-pooling.sh --csv /mnt/user/appdata/proxysql/pooling-log.csv
```

Let it run across a normal traffic period (including any Vercel cold-start
bursts) before drawing conclusions — a snapshot from a quiet moment will
understate real pool pressure.

## What to look for

- `ConnERR` climbing on any backend row: the app pool is exceeding what
  ProxySQL can hand off, or MariaDB itself is refusing connections.
- `ConnUsed` sitting near the hostgroup's `max_connections` cap for
  sustained periods: raise the cap or add rate limiting on the application
  side before it does (this is what `rate-limits` in the roadmap covers).
- `Client_Connections_aborted` or `Server_Connections_aborted` above zero:
  investigate before publication — aborted connections usually mean a
  timeout or TLS mismatch, not normal churn.
- Rising `Latency_us` alongside flat connection counts: backend contention
  (MariaDB itself), not a pooling problem — out of scope for ProxySQL
  tuning.

Once a full traffic cycle has been logged and reviewed, mark
`observe-pooling` `done` in `projects/roadmap.yaml` with a note summarizing
the observed ceiling, and use those numbers to size `rate-limits`.
