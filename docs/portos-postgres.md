# PortOS Postgres on Unraid

Networked PostgreSQL backend for [PortOS](https://github.com/silasfelinus/PortOS) — a private, single-user creative/ops workstation app that normally runs its own local database. This template exists for the case documented in PortOS's `docs/features/network-postgres.md`: a user runs PortOS on more than one machine (a laptop and a desktop, say) and wants both to share one database instead of running two independent local Postgres instances. An Unraid box reachable over Tailscale is a natural place to host that shared instance.

This does **not** package the PortOS application itself — PortOS is a Node/PM2 process, not a container, and stays running on each user machine as usual. Only the database moves to Unraid.

## Before installation

Decide:

- the database name, user, and password every connecting PortOS install will share
- whether this container is reachable only via Tailscale (recommended) or also LAN
- the appdata path for persistent storage

Do not commit real credentials to this repository.

## Why pgvector, not plain postgres

PortOS's creative catalog uses the `vector` Postgres extension for similarity search. The `pgvector/pgvector:pg17` image ships it preinstalled; a stock `postgres` image does not have it and `CREATE EXTENSION vector` will fail. This is the same image PortOS's own local `docker-compose.yml` uses, so a networked install behaves identically to a local one.

## Install

1. Add the XML template from `templates/portos-postgres.xml` to Unraid.
2. Create the appdata directory before first start:
   ```bash
   mkdir -p /mnt/user/appdata/portos-postgres/data
   ```
3. Set `Postgres Database`, `Postgres User`, and `Postgres Password` to real values (do not keep the local-dev default password of `portos` on a networked instance).
4. Leave the host port at `5432` unless it collides with another service; PortOS's `.env` will need to match whatever you choose.
5. Start the container and confirm it becomes healthy:
   ```bash
   docker exec -it PortOS-Postgres pg_isready -U <POSTGRES_USER>
   ```

## Configure each connecting PortOS machine

On every PortOS install that should use this shared database, edit `.env`:

```env
PGMODE=network
PGHOST=<unraid-tailscale-hostname>
PGPORT=5432
PGDATABASE=<same value as POSTGRES_DB above>
PGUSER=<same value as POSTGRES_USER above>
PGPASSWORD=<same value as POSTGRES_PASSWORD above>
```

Use the full MagicDNS name (e.g. `myunraid.foxhound-chicken.ts.net`) if the short Tailscale hostname does not resolve from that machine.

Then run:

```bash
npm run setup:db
```

If the database is reachable but has no PortOS schema yet, `setup:db` offers to apply `server/scripts/init-db.sql` from the connecting PortOS checkout — the schema is bootstrapped by the app, not baked into this container image.

## Quick checks

From any machine that can reach the container:

```bash
psql -h <unraid-tailscale-hostname> -p 5432 -U <POSTGRES_USER> -d <POSTGRES_DB> -c "SELECT 1;"
psql -h <unraid-tailscale-hostname> -p 5432 -U <POSTGRES_USER> -d <POSTGRES_DB> -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

## Persistence

All state lives under the `Postgres Data` path (`/mnt/user/appdata/portos-postgres/data` by default). Back it up like any other stateful appdata — see PortOS's own `docs/BACKUP.md` for how PortOS's application-level backups interact with this database (they are independent: PortOS's rsync snapshots cover `data/` on the app machine, not this container's volume).

## Upgrade policy

Pin the image tag (`pgvector/pgvector:pg17`) rather than tracking `latest`. Before bumping the major Postgres version:

1. Stop every connecting PortOS install (or at minimum pause writes).
2. Take a `pg_dump` of the current container.
3. Start the new container version against a fresh data path, restore the dump, and verify `SELECT version();` and `CREATE EXTENSION IF NOT EXISTS vector;` both succeed.
4. Only then repoint the appdata path / retire the old container.

Never upgrade a shared multi-machine database without a tested dump-and-restore path — a failed in-place major-version upgrade with no separate backup takes down every connected PortOS install at once.

## Never expose this container publicly

This template has no authentication beyond the Postgres password and is designed for Tailscale/LAN-only reachability, matching PortOS's own single-user, private-network trust model. Do not forward its port through your router.

## Publication status

This template is a deployable draft, not yet Community Applications ready. Before publication we will pin a tested image version, perform a clean-install test against a real multi-machine PortOS setup, and confirm the icon format.
