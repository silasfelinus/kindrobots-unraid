# Kind Robots on Unraid

Kind Robots runs as the long-term self-hosted production service on Unraid. Vercel can remain available as a fallback, but `kindrobots.org` is served by the Unraid deployment.

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

### Manual update

Because the container now tracks a registry image, **Force Update** in the Unraid Docker menu is sufficient. Unraid pulls the current `:latest` digest and recreates the container with the saved settings. A server-side `git pull` or `docker build` is no longer required for normal deployment updates.

### Automatic update

The recommended Alexandria automation is the **CA Application Auto Update** plugin, available from the Unraid Apps tab as **Auto Update**. Configure Docker updates for `KindRobots` and use a custom schedule such as every ten minutes:

```cron
*/10 * * * *
```

GitHub builds and publishes after `main` changes; the Unraid updater notices the changed `latest` digest on its next pass, pulls it, and recreates KindRobots with the existing DockerMan settings. No inbound GitHub webhook or public management endpoint on Alexandria is required.

Do not schedule Docker updates to overlap appdata backup jobs.

### See exactly what is running

The published image records the Git commit in an OCI label:

```bash
docker inspect KindRobots --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
```

The container's image ID and repository can be checked with:

```bash
docker inspect KindRobots --format '{{.Config.Image}} {{.Image}}'
```

### Roll back

Every successful publish also creates an immutable `sha-...` tag. To roll back, edit the Unraid container's Repository to the desired tag, for example:

```text
ghcr.io/silasfelinus/kind_robots:sha-1a2b3c4
```

Apply the container, verify it, and return the Repository to `:latest` when ready to resume automatic updates.

## Local checkout and environment

Keep `/mnt/user/appdata/kind_robots` because Alexandria uses it for administrative/database scripts and because `.env` is mounted from it. Normal deployment updates no longer depend on the checkout being current.

Before using Google login at `kindrobots.org`, the existing `GOOGLE_REDIRECT_URI` in `.env` must use the `https://kindrobots.org` origin with the application's exact callback path. The Google OAuth client may retain the Vercel callback at the same time.

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
