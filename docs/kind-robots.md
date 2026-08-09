# Kind Robots on Unraid

This packages the full Kind Robots Nuxt/Nitro application as the long-term self-hosted production service. Vercel can remain online as a parking/fallback deployment during migration, but it is not part of the target request path once `kindrobots.org` moves to Unraid.

## Deployment layout

- Source checkout: `/mnt/user/appdata/kind_robots`
- Runtime image: `kind-robots:local`
- Docker network: `cafepurr`
- Container HTTP port: `3000`
- Default Unraid host/WebUI port: `3009`
- Runtime environment file: `/mnt/user/appdata/kind_robots/.env`, mounted read-only
- Persistent images: `/mnt/user/pc/kindrobots/images`, mounted at `/app/.output/public/images`
- Canonical public origin: `https://kindrobots.org`

The container starts Node with `--env-file-if-exists=/config/kind-robots.env`. This means the existing repo `.env` provides the complete application environment without copying every variable into the Unraid template. Values explicitly configured as Docker environment variables in the Unraid WebGUI take precedence over values loaded from the file, so deployment-specific settings such as `APP_BASE_URL` and `AUTH_ORIGIN` remain visible and editable in DockerMan.

The `.env` file is excluded from the Docker build context. It is mounted only when the container runs and is never baked into the image.

## 1. Prepare the repo and environment

The repo is expected at:

```text
/mnt/user/appdata/kind_robots
```

Keep the existing `.env` there. Do not copy its secret values into the Unraid template.

Before the production cutover, update the existing `GOOGLE_REDIRECT_URI` value in `.env`. Preserve its current callback path exactly and replace only the old scheme/host with:

```text
https://kindrobots.org
```

For example, if the current value ends in `/some/oauth/callback`, the new value must end in that identical path. The callback path is application behavior, not a deployment guess.

`APP_BASE_URL` and `AUTH_ORIGIN` do not need to be edited in `.env` when using the supplied Unraid template because DockerMan supplies both as `https://kindrobots.org` and those process environment values win over the mounted file.

## 2. Build the local production image

From the Unraid terminal:

```bash
cd /mnt/user/appdata/kind_robots
git pull --ff-only
docker build --pull -t kind-robots:local .
```

The Dockerfile uses Node 24 and produces the Nuxt/Nitro production build. The runtime image reads the environment only when the container starts.

The image is deliberately local for this first self-hosted deployment. This avoids adding a registry publishing pipeline or registry credentials to the migration. A future catalog task can publish a versioned image once the deployment has been proven on Alexandria.

## 3. Install the DockerMan template

The catalog template is:

```text
templates/kind-robots.xml
```

For a local development install, copy that XML into Unraid's saved user-template directory as a file such as:

```text
/boot/config/plugins/dockerMan/templates-user/my-kind-robots.xml
```

Then open **Docker → Add Container** and select the KindRobots user template.

Unraid persists container configuration in its Docker template XML, so after the first install the port, paths, public URL, auth origin, networking, and any additional variables you add are editable from the normal Unraid Docker control panel.

## 4. Verify the DockerMan settings

The supplied defaults are:

| Setting | Default |
| --- | --- |
| Repository | `kind-robots:local` |
| Network | `cafepurr` |
| WebUI | `http://<unraid-ip>:3009` |
| Web Port | `3009` → container `3000` |
| Environment File | `/mnt/user/appdata/kind_robots/.env` → `/config/kind-robots.env` read-only |
| Media Images | `/mnt/user/pc/kindrobots/images` → `/app/.output/public/images` |
| Public App URL | `https://kindrobots.org` |
| Auth Origin | `https://kindrobots.org` |

Do not expose port `3009` directly to the public internet. The public path should terminate HTTPS at the existing reverse-proxy layer and proxy to the Unraid host/container privately.

If another deployment-specific environment variable later needs to differ from `.env`, add it in the Unraid template as a Docker **Variable**. It will override the same key in the mounted file without requiring the whole `.env` to be duplicated into DockerMan.

## 5. Test before DNS changes

Start the container and check its logs from the Docker page. On the LAN, verify:

```text
http://<unraid-ip>:3009/
http://<unraid-ip>:3009/api/health/database
```

Also verify at least one database-backed page/API and a few existing `/images/...` assets. The image mount is persistent outside `docker.img`, and `/app/public` in the runtime image points to the same built public tree so code using a relative `public/images` path reaches the mounted media directory.

Next, configure the HTTPS reverse proxy for `kindrobots.org` and test the proxy target before changing public DNS. A temporary local hosts-file override or a private test hostname can exercise the full proxy/TLS path while the public domain still points elsewhere.

## 6. Update Google OAuth

In the Google Cloud OAuth client used by Kind Robots:

1. Add the exact new `GOOGLE_REDIRECT_URI` from `.env` to **Authorized redirect URIs**.
2. If that OAuth client has an **Authorized JavaScript origins** list, add `https://kindrobots.org` there as well.
3. Keep the old Vercel redirect URI during the migration so the parked deployment remains usable until cutover is verified.
4. Test Google sign-in through the Unraid/reverse-proxy path before removing any old callback.

OAuth settings are an external account change and are intentionally not encoded into the repository or template.

## 7. Public cutover

DNS is a human-gated production action. After the local application, database health, media, HTTPS proxy, and Google login are all healthy:

1. Point `kindrobots.org` at the public endpoint that reaches the reverse proxy in front of Unraid.
2. Confirm the public certificate is valid for `kindrobots.org`.
3. Verify the homepage, `/api/health/database`, a database-backed route, media assets, and Google login from the public domain.
4. Keep `kind-robots.vercel.app` available as a fallback until the self-hosted deployment has had a stable observation period.

The current Vercel project does not need `kindrobots.org` removed from it during this cutover because the domain is not currently attached there.

## Updating Kind Robots later

For a normal code update:

```bash
cd /mnt/user/appdata/kind_robots
git pull --ff-only
docker build --pull -t kind-robots:local .
```

Then use the Unraid Docker page to recreate/apply the KindRobots container from its saved template so it starts from the new image while retaining all DockerMan settings and host mounts.

Do not put `.env` into the image or commit it to Git. The mounted file plus explicit DockerMan overrides is the intended configuration contract.
