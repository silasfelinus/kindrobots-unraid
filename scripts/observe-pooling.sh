#!/usr/bin/env bash
# Snapshot ProxySQL frontend/backend pooling stats for the database-resilience
# roadmap's observe-pooling task (projects/roadmap.yaml).
#
# Run on the Unraid host (or anywhere with `docker exec` access to the
# proxysql container). Reads the admin interface on 127.0.0.1:6032, which is
# never published, so this must run alongside the container.
#
# Usage:
#   ./scripts/observe-pooling.sh                  # human-readable snapshot to stdout
#   ./scripts/observe-pooling.sh --csv FILE.csv    # append one summary row to FILE.csv
#
# Required env vars:
#   PROXYSQL_ADMIN_USER      admin interface user (default: admin)
#   PROXYSQL_ADMIN_PASSWORD  admin interface password
#   PROXYSQL_CONTAINER       container name (default: proxysql)

set -euo pipefail

CONTAINER="${PROXYSQL_CONTAINER:-proxysql}"
ADMIN_USER="${PROXYSQL_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${PROXYSQL_ADMIN_PASSWORD:-}"
CSV_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --csv)
      CSV_FILE="${2:?--csv requires a file path}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$ADMIN_PASSWORD" ]; then
  echo "PROXYSQL_ADMIN_PASSWORD is required (never hardcode it in this repo)." >&2
  exit 1
fi

run_admin_sql() {
  docker exec -i "$CONTAINER" \
    mariadb -h 127.0.0.1 -P 6032 -u "$ADMIN_USER" -p"$ADMIN_PASSWORD" \
    --batch --raw -N -e "$1"
}

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

pool_report="$(run_admin_sql "SELECT hostgroup, srv_host, srv_port, status, ConnUsed, ConnFree, ConnOK, ConnERR, Queries, Latency_us FROM stats_mysql_connection_pool;")"
global_report="$(run_admin_sql "SELECT Variable_Name, Variable_Value FROM stats_mysql_global WHERE Variable_Name IN ('Client_Connections_connected','Client_Connections_created','Client_Connections_aborted','Server_Connections_connected','Server_Connections_created','Server_Connections_aborted','Questions','Slow_queries');")"

if [ -n "$CSV_FILE" ]; then
  # One flattened row per snapshot: timestamp + every stats_mysql_global value in a stable order.
  header="timestamp,client_connections_connected,client_connections_created,client_connections_aborted,server_connections_connected,server_connections_created,server_connections_aborted,questions,slow_queries"
  get_val() { echo "$global_report" | awk -F'\t' -v k="$1" '$1==k{print $2}'; }
  row="$timestamp,$(get_val Client_Connections_connected),$(get_val Client_Connections_created),$(get_val Client_Connections_aborted),$(get_val Server_Connections_connected),$(get_val Server_Connections_created),$(get_val Server_Connections_aborted),$(get_val Questions),$(get_val Slow_queries)"

  if [ ! -f "$CSV_FILE" ]; then
    echo "$header" > "$CSV_FILE"
  fi
  echo "$row" >> "$CSV_FILE"
  echo "Appended snapshot at $timestamp to $CSV_FILE"
else
  echo "=== ProxySQL pooling snapshot: $timestamp ==="
  echo
  echo "--- stats_mysql_connection_pool ---"
  echo "$pool_report"
  echo
  echo "--- stats_mysql_global (connection counters) ---"
  echo "$global_report"
fi
