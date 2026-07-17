# Ollama on Unraid

Self-hosted local LLM server for the Kind Robots ecosystem. [Ollama](https://github.com/ollama/ollama) exposes a simple HTTP API (port `11434`) for pulling and running open-weight models (Llama, Mistral, Qwen, etc.) without depending on a hosted API provider.

Two templates cover the two realistic deployment modes:

- `templates/ollama.xml` — CPU-only. No extra Unraid plugin required. Works everywhere but is slow for anything beyond small models.
- `templates/ollama-nvidia.xml` — NVIDIA GPU-accelerated, via the community **Nvidia-Driver** Unraid plugin (`--runtime=nvidia`). Install that plugin first from Community Applications.

Both use the official `ollama/ollama` image and differ only in `ExtraParams`/GPU environment variables — pick one, not both, per install (they share the same default appdata path, so running both against the same path simultaneously is not supported).

## Before installation

- Decide CPU or NVIDIA mode based on available hardware. If unsure whether GPU passthrough works, install the CPU template first — switching later just means re-adding the other template pointed at the same `Ollama Models` path.
- For the NVIDIA template: install the "Nvidia-Driver" plugin from Community Applications and confirm `nvidia-smi` works in the Unraid terminal before starting the container.
- Plan storage: models range from ~1GB (small quantized models) to 40GB+ (large models). The `Ollama Models` path holds every pulled model.

## Install

1. Add the XML template (`templates/ollama.xml` or `templates/ollama-nvidia.xml`) to Unraid.
2. Create the appdata directory before first start:
   ```bash
   mkdir -p /mnt/user/appdata/ollama/data
   ```
3. Start the container.
4. Pull a model and confirm it responds:
   ```bash
   docker exec -it Ollama ollama pull llama3.2
   docker exec -it Ollama ollama run llama3.2 "hello"
   ```
   (use container name `Ollama-Nvidia` for the GPU template)

## Quick checks

From any machine that can reach the container:

```bash
curl http://<unraid-host>:11434/api/tags
```

Should return the list of locally pulled models as JSON. The bare root URL (`http://<unraid-host>:11434/`) returns the plain-text `Ollama is running` health check — that is the correct response, not an error.

For the NVIDIA template, confirm the GPU is actually in use during a run:

```bash
docker exec -it Ollama-Nvidia nvidia-smi
```

should show the `ollama` process using GPU memory while a generation is in flight. If it shows no process, the `--runtime=nvidia` passthrough did not take — recheck the Nvidia-Driver plugin installation before assuming the template is broken.

## Persistence

All state (pulled models, Ollama's internal config) lives under the `Ollama Models` path (`/mnt/user/appdata/ollama/data` by default). Removing the container without removing this path preserves every pulled model for the next start.

## Never expose this container publicly

The Ollama API has no authentication. Keep it on the Unraid LAN or reachable only over Tailscale, matching the trust model used by the other templates in this catalog. Do not forward its port through your router.

## Upgrade policy

Pin the image tag before Community Applications publication rather than tracking `latest` indefinitely; `ollama/ollama:latest` is acceptable for the current tested-draft stage since the API has been stable across releases, but revisit before marking this template `community-apps-ready`.

## Publication status

Deployable draft, not yet Community Applications ready. Before publication: a clean-install test of both templates on a real Unraid box (one with the Nvidia-Driver plugin, one without), a pinned image tag, and confirmation the icon renders correctly in the Unraid UI.
