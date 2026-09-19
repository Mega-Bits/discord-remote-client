# Discord Remote Client

Docker image for running the official Discord Linux client with Vencord in a lightweight remote desktop that is reachable over VNC.

## Included

- Official Discord Linux `.deb`
- Vencord
- TigerVNC / Xtigervnc
- Openbox
- DBus
- Persistent Discord/Vencord profile
- GitHub Actions image build for GHCR

## How startup works

The current Discord Linux package may bootstrap/update the actual application into the user profile. The container therefore patches Vencord at runtime, after Discord has finished creating its `~/.config/discord/app-*/resources` directory.

On first startup:

1. TigerVNC and Openbox start.
2. Discord starts once and initializes/downloads its application files.
3. The container waits until the downloaded application directory has stopped changing for a short period.
4. Discord is cleanly stopped.
5. The official Vencord CLI patches the stable Discord install using its native Linux auto-discovery.
6. Discord starts again under a supervisor.

The Vencord installer itself supports the `~/.config/discord/app-*` layout, so the container does not try to guess an `app.asar` path.

## Discord cannot stay closed

Discord runs under a supervisor loop. If a user closes the Discord window and the process exits, it is automatically started again after a short delay.

The window is also automatically maximized whenever it appears.

## Resolution and Remote Desktop Manager

TigerVNC accepts VNC `SetDesktopSize` requests. If the VNC viewer used by Remote Desktop Manager sends remote-resize requests, the actual remote desktop resolution can follow the client window/monitor size rather than merely scaling a fixed framebuffer.

The initial/fallback resolution is controlled with:

```env
SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080
```

A VNC server cannot discover the local monitor resolution on its own. The VNC client must send a desktop-resize request. If the RDM VNC viewer only offers Smart Sizing, it scales the image to the RDM window but does not change the remote framebuffer resolution. In that case either set `SCREEN_WIDTH`/`SCREEN_HEIGHT` to the monitor's native resolution or use a VNC viewer in RDM that supports remote resize.

## Image

```text
ghcr.io/mega-bits/discord-remote-client:latest
```

The image is currently built for `linux/amd64`.

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

The default Compose file publishes VNC only on the server loopback interface:

```text
127.0.0.1:5900
```

Use an SSH tunnel in Remote Desktop Manager:

```text
Local:  127.0.0.1:5900
Remote: 127.0.0.1:5900
```

Then connect the VNC session to `127.0.0.1:5900`.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `Europe/Berlin` | Container timezone |
| `SCREEN_WIDTH` | `1920` | Initial/fallback VNC desktop width |
| `SCREEN_HEIGHT` | `1080` | Initial/fallback VNC desktop height |
| `SCREEN_DEPTH` | `24` | X11 color depth |
| `VNC_FRAME_RATE` | `60` | Maximum VNC update frame rate |
| `VNC_PASSWORD` | `changeme` | VNC authentication password |
| `DISCORD_BOOTSTRAP_TIMEOUT` | `300` | Maximum seconds for first-run Discord initialization |
| `DISCORD_BOOTSTRAP_STABLE_SECONDS` | `12` | Seconds the downloaded app directory must remain unchanged |
| `DISCORD_RESTART_DELAY` | `2` | Delay before Discord is restarted after being closed |

Discord, login state and Vencord data are persisted in the `discord_config` volume.

## Security

The Compose file binds VNC to `127.0.0.1` on the Docker host. Keep it that way and access it through SSH, WireGuard, Tailscale or another trusted tunnel.

Classic VNC password authentication only uses the first eight password characters. The SSH/VPN layer should therefore be treated as the primary security boundary.

## Vencord

Vencord is a third-party Discord client modification. Its use may be subject to Discord's terms and Vencord's own support guidance.
