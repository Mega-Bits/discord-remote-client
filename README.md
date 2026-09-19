# Discord Remote Client

Lightweight Docker image for running the official Discord Linux client with Vencord on a virtual X11 desktop and controlling it remotely over VNC.

## How it works

Discord's current Linux package is a bootstrapper. The Docker image installs that official `.deb`, but Vencord is deliberately **not** patched during the image build.

On container startup:

1. Xvfb, Openbox and x11vnc start.
2. If Discord has not initialized its application files yet, Discord is started once so it can download them into `~/.config/discord/app-<version>/`.
3. The bootstrap Discord process is stopped.
4. Vencord patches the downloaded Discord application in `~/.config/discord`.
5. Discord starts normally.

Because `/home/discord/.config` is persisted, the downloaded Discord application, login state and Vencord data survive container restarts. If Discord downloads a new application version later, the next container restart patches that version as well.

Vencord officially supports Discord's official Linux `.deb` package; Snap is not supported.

## Image

```text
ghcr.io/mega-bits/discord-remote-client:latest
```

The image is built for `linux/amd64`.

## Portainer / Docker Compose

Create a `.env` file or define `VNC_PASSWORD` in Portainer:

```env
VNC_PASSWORD=change-me
```

Then deploy:

```bash
docker compose pull
docker compose up -d
```

The first start can take longer because Discord downloads its actual application files before Vencord is patched.

The default compose file publishes VNC only on the server loopback interface:

```text
127.0.0.1:5900
```

Use an SSH tunnel in Remote Desktop Manager to reach the VNC service. Do not expose plain VNC directly to the public internet.

Example SSH tunnel:

```text
Local: 127.0.0.1:5900
Remote: 127.0.0.1:5900
```

Then connect the VNC session to `127.0.0.1:5900`.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `Europe/Berlin` | Container timezone |
| `SCREEN_WIDTH` | `1600` | Virtual screen width |
| `SCREEN_HEIGHT` | `900` | Virtual screen height |
| `SCREEN_DEPTH` | `24` | X11 color depth |
| `VNC_PASSWORD` | `changeme` | VNC password |
| `DISCORD_BOOTSTRAP_TIMEOUT` | `300` | Seconds to wait for Discord's first-run download |

Discord and Vencord data are persisted in the `discord_config` Docker volume.

## Updating

The GitHub Action rebuilds and publishes the image whenever `main` changes.

To update the container:

```bash
docker compose pull
docker compose up -d
```

If Discord has downloaded a new internal application version, restarting the container lets the entrypoint detect and patch the newest version with Vencord.

## Security

VNC authentication is not transport encryption. Keep port 5900 bound to localhost and access it through SSH, WireGuard, Tailscale, or another trusted private network.

Classic VNC authentication effectively uses only the first eight password characters, so the SSH/VPN layer is the important security boundary.

## Vencord

Vencord is a third-party Discord client modification. Its use may be subject to Discord's terms and Vencord's own support guidance.
