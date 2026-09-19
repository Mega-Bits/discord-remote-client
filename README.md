# Discord Remote Client

Docker image for running the official Discord Linux client with Vencord in a lightweight remote desktop that is reachable over VNC.

## Included

- Official Discord Linux `.deb`
- Vencord
- TigerVNC / Xtigervnc
- Openbox
- Mesa llvmpipe software rendering
- DBus
- Persistent Discord/Vencord profile
- GitHub Actions image build for GHCR

## How startup works

Discord's Linux package bootstraps the actual application into the user profile. Vencord is patched only after Discord has completed a clean, unmodified first start.

For every new Discord `app-<version>`:

1. TigerVNC and Openbox start.
2. If that Discord version has not completed bootstrap yet, an existing Vencord patch is temporarily removed.
3. Discord starts unmodified.
4. The container waits until the main Discord renderer has finished loading.
5. Discord gets an additional grace period (45 seconds by default) to finish modules, updater work and first-run setup.
6. A per-version bootstrap marker is written.
7. Discord is stopped cleanly.
8. Vencord patches Discord and the resulting `_app.asar` is verified.
9. Discord starts under a supervisor.

This also repairs older persistent volumes that were patched too early: if no bootstrap-complete marker exists for the current Discord version, Vencord is temporarily unpatched and the clean bootstrap is run once again.

## Discord cannot stay closed

Discord runs under a supervisor loop. If a user closes the Discord process, it automatically starts again after a short delay. Its window is also automatically maximized.

## Resolution and Remote Desktop Manager

TigerVNC accepts VNC `SetDesktopSize` requests. If the VNC viewer used by Remote Desktop Manager sends remote-resize requests, the remote framebuffer can follow the RDM window/monitor size.

Fallback resolution:

```env
SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080
```

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
docker compose up -d --force-recreate
```

The default Compose file publishes VNC only on the server loopback interface:

```text
127.0.0.1:5900
```

Use an SSH tunnel in Remote Desktop Manager and connect the VNC session to `127.0.0.1:5900`.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `Europe/Berlin` | Container timezone |
| `SCREEN_WIDTH` | `1920` | Initial/fallback VNC desktop width |
| `SCREEN_HEIGHT` | `1080` | Initial/fallback VNC desktop height |
| `SCREEN_DEPTH` | `24` | X11 color depth |
| `VNC_FRAME_RATE` | `60` | Maximum VNC update frame rate |
| `VNC_PASSWORD` | `changeme` | VNC authentication password |
| `DISCORD_BOOTSTRAP_TIMEOUT` | `300` | Maximum seconds to wait for Discord's main renderer during first-run bootstrap |
| `DISCORD_BOOTSTRAP_GRACE_SECONDS` | `45` | Extra time after the main renderer loads before Discord is stopped and patched |
| `DISCORD_RESTART_DELAY` | `2` | Delay before Discord is restarted after being closed |

Discord, login state, bootstrap markers and Vencord data are persisted in the `discord_config` volume.

## Security

The Compose file binds VNC to `127.0.0.1` on the Docker host. Keep it that way and access it through SSH, WireGuard, Tailscale or another trusted tunnel.

Classic VNC password authentication only uses the first eight password characters. The SSH/VPN layer should therefore be treated as the primary security boundary.

## Vencord

Vencord is a third-party Discord client modification. Its use may be subject to Discord's terms and Vencord's own support guidance.
