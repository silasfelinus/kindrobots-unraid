# ComfyUI on Unraid

GPU-accelerated node-based image/video generation for the Kind Robots ecosystem. [ComfyUI](https://github.com/silasfelinus/ComfyUI) has no official first-party Docker image, so this template packages the community-maintained [`mmartial/comfyui-nvidia-docker`](https://github.com/mmartial/ComfyUI-Nvidia-Docker) image instead — the same one used by the widely-deployed Unraid Community Applications template of the same name. This is an exception to the catalog's "prefer official upstream images" principle, noted here rather than silently: there is currently no other actively maintained path to a containerized ComfyUI.

- Template: `templates/comfyui-nvidia.xml`
- Upstream image: `mmartial/comfyui-nvidia-docker`
- Kind Robots ComfyUI fork (tracked, not containerized by this template): `https://github.com/silasfelinus/ComfyUI`
- WebUI port `8188`.
- Requires the community **Nvidia-Driver** Unraid plugin and a passed-through NVIDIA GPU. There is no CPU-only variant of this template — CPU inference for image/video diffusion models is impractically slow.

## Before installation

- Install the "Nvidia-Driver" plugin from Community Applications and confirm `nvidia-smi` works in the Unraid terminal before starting the container.
- Plan storage for the **Base Directory** path: checkpoints, LoRAs, VAEs, and other models commonly run several GB each, and a working set can easily reach 50GB+. Point it at bulk storage rather than the cache pool if space is tight.
- The **Run Directory** path is disposable — it holds the Python venv and the ComfyUI install itself, both rebuilt automatically on first start. Only the **Base Directory** needs backing up.

## Install

1. Add the XML template (`templates/comfyui-nvidia.xml`) to Unraid.
2. Create the appdata directories before first start:
   ```bash
   mkdir -p /mnt/user/appdata/comfyui-nvidia/run
   mkdir -p /mnt/user/appdata/comfyui-nvidia/basedir
   ```
3. Start the container. The first start downloads and installs ComfyUI plus a Python virtual environment into the Run path — this can take several minutes with no visible progress in the Unraid UI. Watch the container log, not the WebUI, until you see it start listening on port 8188. Do not restart the container just because the WebUI isn't answering yet.
4. Open `http://<unraid-host>:8188/` once the log shows the server has started.
5. Models go under the Base Directory's `models/` subfolders (`checkpoints/`, `loras/`, `vae/`, `controlnet/`, etc. — mirrors ComfyUI's standard `models/` layout). Custom nodes install through the in-app ComfyUI Manager (subject to the `SECURITY_LEVEL` setting) or by dropping them into the Base Directory's `custom_nodes/`.

## Quick checks

```bash
curl -sf http://<unraid-host>:8188/system_stats
```

Should return JSON describing the running system, including GPU device info. If `devices` is empty or shows a CPU-only entry, the `--runtime=nvidia` GPU passthrough did not take — recheck the Nvidia-Driver plugin before assuming the template is broken.

```bash
docker exec -it ComfyUI-Nvidia nvidia-smi
```

Should list the container's GPU and show it in use while a generation is running.

## Persistence

- **Run Directory** (`/mnt/user/appdata/comfyui-nvidia/run` by default): venv + ComfyUI source. Disposable — deleting it just means a slower next start while it reinstalls.
- **Base Directory** (`/mnt/user/appdata/comfyui-nvidia/basedir` by default): models, custom_nodes, input, output. This is the data that matters. Removing the container without removing this path preserves every model and custom node for the next start.

## Never expose this container publicly

The ComfyUI Manager can install and run arbitrary custom nodes, and the API itself has no authentication. Keep this on the Unraid LAN or reachable only over Tailscale, matching the trust model used by the other templates in this catalog. Do not forward its port through your router.

## Upgrade policy

Tracking `mmartial/comfyui-nvidia-docker:latest` is acceptable for the current tested-draft stage since the image itself handles ComfyUI/dependency updates internally (see `DISABLE_UPGRADES` if you need to pin a working state). Revisit pinning a specific image tag before marking this template `community-apps-ready`.

## Publication status

Deployable draft, not yet Community Applications ready. Before publication: a clean-install test on a real Unraid box with the Nvidia-Driver plugin, confirmation the icon renders correctly in the Unraid UI, and a decision on whether to keep depending on a third-party image or eventually publish a Kind-Robots-maintained one.
