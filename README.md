# Kind Robots for Unraid

A curated catalog of Unraid templates for the Kind Robots self-hosted ecosystem.

This repository is the **master integration layer**. Application source remains in its upstream repository; this catalog provides consistent Unraid installation templates, documentation, validation, upgrade notes, and a path toward Community Applications publication.

## First app: ProxySQL

ProxySQL is the first infrastructure template because it protects the MariaDB backend from serverless connection storms and gives the stack a controlled database entry point.

- Template: `templates/proxysql.xml`
- Setup guide: `docs/proxysql.md`
- Pooling observability: `docs/observability.md` (`scripts/observe-pooling.sh`)
- Upstream image: `proxysql/proxysql`
- Admin port `6032` must remain private.
- MySQL client port `6033` is the application-facing port.

## Catalog layout

```text
kindrobots-unraid/
├── templates/             # Installable Unraid XML templates
├── docs/                  # Per-app setup and operations guides
├── projects/catalog.yaml  # Source repositories and publication status
├── projects/roadmap.yaml  # Work queue for future templates
└── .github/workflows/     # Template validation
```

## Planned catalog

The initial registry covers the current Kind Robots ecosystem, including Kind Robots, Conductor, PortOS, ProxySQL, ComfyUI, Forge, Ollama helpers, backup services, and supporting projects. Entries begin as `discovery`, advance through `template`, `tested`, and `community-apps-ready`, and are published only after their security, persistence, networking, and upgrade behavior are documented.

## Add the template repository to Unraid

During development, templates can be installed from their raw XML URLs or copied into Unraid's Docker template directory. Community Applications publication will be added after templates have been tested on a clean Unraid system.

## Principles

1. Prefer official upstream images.
2. Never bake secrets into templates or repositories.
3. Persist data under `/mnt/user/appdata/<app>`.
4. Expose only the ports users actually need.
5. Document backup, restore, health checks, and upgrades.
6. Pin stable image versions before a template is marked publication-ready.
7. Treat one-user home deployments and unexpected viral load as two points on the same architecture path.

## Status

This catalog is under active construction. ProxySQL is the first deployable draft; the remaining projects are registered for systematic packaging.
