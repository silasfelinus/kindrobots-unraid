# Kind Robots on Unraid

Kind Robots runs as the long-term self-hosted production service on Unraid. `kindrobots.org` is served by the Unraid deployment.

## Deployment layout

- Source/admin checkout: `/mnt/user/appdata/kind_robots`
- Runtime image: `ghcr.io/silasfelinus/kind_robots:latest`
- Immutable image tags: `ghcr.io/silasfelinus/kind_robots:sha-<commit>`
- Docker network: `cafepurr`
- Container HTTP port: `3000`
- Default Unraid host/WebUI port: `3009`
- Runtime environment file: `/mnt/user/appdata/kind_robots/.env`, mounted read-only
- Persistent images: `/mnt/user/pc/kindrobots/images`, mounted at `/app/.output/public/images`
- Canonical public origin: `https://kindrobots.org`

The container starts Node with `--env-file-if-exists=/config/kind-robots.env`. The existing repo `.env` therefore supplies the complete application environment without copying every variable into the Unraid template. Docker environment variables configured in the Unraid WebGUI take precedence, so deployment-specific settings such as `APP_BASE_URL` and `AUTH_ORIGIN` remain visible and editable in DockerMan.

The `.env` file is excluded from the Docker build context and is never baked into the published image.

## Production image publishing

The `kind_robots` repository publishes its Docker image from GitHub Actions whenever `main` changes. A successful build publishes:

- `ghcr.io/silasfelinus/kind_robots:latest` for normal production updates;
- `ghcr.io/silasfelinus/kind_robots:sha-<short-commit>` as an immutable rollback target.

The image also carries OCI labels containing the source repository and exact Git revision. If a Docker build fails, no new `latest` image is published, so Unraid remains on the last deployable image.

### One-time GHCR visibility gate

GitHub Container Registry creates a new package as private by default. The first published `kind_robots` package must be made **Public** once so Alexandria can pull it anonymously:

1. Open the `kind_robots` repository on GitHub and select its **Packages** entry.
2. Open the `kind_robots` container package and choose **Package settings**.
3. Under **Danger Zone**, choose **Change visibility → Public** and confirm.

Making a package public is irreversible on GitHub, so this remains a deliberate human action. The repository and production image contain no `.env` or runtime secrets.

## Install or migrate the DockerMan template

The catalog template is `templates/kind-robots.xml`. To refresh Alexandria's saved user template:

```bash
curl -fsSL https://raw.githubusercontent.com/silasfelinus/kindrobots-unraid/main/templates/kind-robots.xml \
  -o /boot/config/plugins/dockerMan/templates-user/my-kind-robots.xml
```

Then open **Docker → Add Container** and select the KindRobots user template. For an existing locally built KindRobots container, edit/recreate it after the GHCR package is public so its Repository becomes:

```text
ghcr.io/silasfelinus/kind_robots:latest
```

Unraid preserves the port, paths, public URL, auth origin, networking, and any additional DockerMan variables in its saved template.

## DockerMan defaults

| Setting | Default |
| --- | --- |
| Repository | `ghcr.io/silasfelinus/kind_robots:latest` |
| Network | `cafepurr` |
| WebUI | `http://<unraid-ip>:3009` |
| Web Port | `3009` → container `3000` |
| Environment File | `/mnt/user/appdata/kind_robots/.env` → `/config/kind-robots.env` read-only |
| Media Images | `/mnt/user/pc/kindrobots/images` → `/app/.output/public/images` |
| Public App URL | `https://kindrobots.org` |
| Auth Origin | `https://kindrobots.org` |

Do not expose port `3009` directly to the public internet. Traefik should reach the container over `cafepurr` as `http://KindRobots:3000`.

If another deployment-specific environment variable later needs to differ from `.env`, add it in the Unraid template as a Docker **Variable**. It overrides the same key from the mounted file without duplicating the full `.env` into DockerMan.

## Updating Kind Robots

Kind Robots is schema-bearing software. Replacing the application container without first applying the matching image's Prisma migrations can put new code in front of an old or partially migrated schema. The canonical Alexandria update path is therefore the guarded deployer in the `kind_robots` repository, not a generic Docker image updater.

### Automatic update

Use the Unraid **User Scripts** plugin to run this launcher every five minutes:

```bash
#!/bin/bash
exec /bin/bash /mnt/user/appdata/kind_robots/scripts/unraid-user-script.sh
```

The launcher fast-forwards the clean production checkout and delegates to `scripts/deploy-unraid.sh`. That deployer:

1. pulls the current GHCR image;
2. runs that exact image's pending Prisma migrations with the isolated migration credential;
3. stops immediately if migration or repair fails, leaving the previous application container in place;
4. only after migration succeeds asks Unraid DockerMan to recreate `KindRobots`;
5. waits for Docker health before declaring the update complete.

Do **not** enable **CA Application Auto Update** for the `KindRobots` container. It can notice a new `:latest` digest and replace the container without running the migration gate first. The plugin remains fine for unrelated containers that do not need Kind Robots' schema-aware deployment contract.

Do **not** use DockerMan **Force Update** as the routine Kind Robots update path for the same reason. It knows how to recreate a container, but it does not know how to apply Prisma migrations.

### Manual guarded update

When an immediate deployment check is needed, use the same guarded path directly:

```bash
cd /mnt/user/appdata/kind_robots
git switch main
git pull --ff-only
bash scripts/deploy-unraid.sh
```

This command is intentionally migration-aware. If it reports a migration failure, read that failure before taking any direct database action; do not bypass it with Force Update.

### See exactly what is running

The published image records the Git commit in an OCI label:

```bash
docker inspect KindRobots --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
```

The container's image ID, repository, and health can be checked with:

```bash
docker inspect KindRobots --format '{{.Config.Image}} {{.Image}} {{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'
```

### Roll back

Every successful publish also creates an immutable `sha-...` tag. A rollback is not automatically schema-safe: the database may already contain migrations newer than the image being selected. Use the Kind Robots migration/deployment runbook to evaluate compatibility before changing the production Repository tag. Do not treat Docker image rollback and database rollback as the same operation.

## Local checkout and environment

Keep `/mnt/user/appdata/kind_robots` because Alexandria uses it for administrative/database scripts and because `.env` is mounted from it. The guarded User Scripts launcher also keeps this checkout current so the production deploy logic itself tracks `main`.

Before using Google login at `kindrobots.org`, the existing `GOOGLE_REDIRECT_URI` in `.env` must use the `https://kindrobots.org` origin with the application's exact callback path.

`APP_BASE_URL` and `AUTH_ORIGIN` do not need to be duplicated in `.env` because DockerMan supplies both as `https://kindrobots.org` and process environment values take precedence.

## Verification

After an update, verify:

```text
http://<unraid-ip>:3009/
http://<unraid-ip>:3009/api/health/database
https://kindrobots.org/
```

Also verify a database-backed page/API, several existing `/images/...` assets, and Google login. The persistent image library lives outside `docker.img`, and `/app/public` in the runtime image points to the built public tree so code using `public/images` reaches the mounted media directory.

Do not commit `.env`, registry credentials, or production secrets. The mounted `.env` plus explicit DockerMan overrides is the intended configuration contract.