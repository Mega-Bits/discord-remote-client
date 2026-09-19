# Discord Remote Client

Lightweight Docker image for running the official Discord Linux client with Vencord on a virtual X11 desktop and controlling it remotely over VNC.

## Included

- Official Discord Linux client
- Vencord
- Xvfb virtual display
- Openbox window manager
- x11vnc
- DBus
- Persistent Discord/Vencord configuration
- GitHub Actions build and publish to GHCR

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
docker compose up -d
```

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

Environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `Europe/Berlin` | Container timezone |
| `SCREEN_WIDTH` | `1600` | Virtual screen width |
| `SCREEN_HEIGHT` | `900` | Virtual screen height |
| `SCREEN_DEPTH` | `24` | X11 color depth |
| `VNC_PASSWORD` | required | VNC password |

Discord data is persisted in the `discord_config` Docker volume.

## Updating

The GitHub Action rebuilds and publishes the image when `main` changes. Re-pulling `latest` updates Discord and Vencord because both are installed during the image build.

```bash
docker compose pull
docker compose up -d
```

## Security

VNC authentication is not a substitute for transport encryption. Keep port 5900 bound to localhost and access it through SSH, WireGuard, Tailscale, or another trusted private network.

## Vencord

Vencord is a third-party Discord client modification. Its use may be subject to Discord's terms and Vencord's own support guidance.
