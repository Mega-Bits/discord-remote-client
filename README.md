# Discord Remote Client

Lightweight Docker image for running **Vesktop** with its built-in Vencord integration in a VNC-accessible Linux desktop.

## Stack

- Vesktop 1.6.7
- Built-in Vencord integration
- TigerVNC / Xtigervnc
- Openbox
- SwiftShader CPU rendering for Electron
- Mesa llvmpipe for the X11 desktop
- DBus
- Persistent user configuration
- GitHub Actions image build for GHCR

The image is built for `linux/amd64`.

## Image

```text
ghcr.io/mega-bits/discord-remote-client:latest
```

## Portainer / Docker Compose

Set a VNC password:

```env
VNC_PASSWORD=change-me
```

Then deploy:

```bash
docker compose pull
docker compose up -d --force-recreate
```

The Compose file binds VNC only to the Docker host loopback interface:

```text
127.0.0.1:5900
```

Use an SSH tunnel, VPN or another trusted path from Remote Desktop Manager to the host and connect VNC to `127.0.0.1:5900`.

## Persistence

The complete user configuration directory is stored in the `discord_config` volume:

```text
/home/discord/.config
```

That includes Vesktop settings, Vencord settings and the Discord web session/login state used by Vesktop.

## Resolution

TigerVNC accepts remote desktop resize requests through `SetDesktopSize`.

Fallback resolution:

```env
SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080
```

If Remote Desktop Manager sends remote-resize requests, the framebuffer can follow the RDM window or monitor size.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `Europe/Berlin` | Container timezone |
| `SCREEN_WIDTH` | `1920` | Initial/fallback desktop width |
| `SCREEN_HEIGHT` | `1080` | Initial/fallback desktop height |
| `SCREEN_DEPTH` | `24` | X11 color depth |
| `VNC_FRAME_RATE` | `60` | Maximum TigerVNC update frame rate |
| `VNC_PASSWORD` | `changeme` | VNC authentication password |
| `VESKTOP_RESTART_DELAY` | `2` | Delay before Vesktop is restarted after closing |

## CPU-only rendering

The host does not need a physical GPU. Vesktop/Electron is launched through SwiftShader:

```text
--use-gl=angle
--use-angle=swiftshader
--enable-unsafe-swiftshader
```

The X11 desktop itself uses Mesa llvmpipe.

## Security

Keep VNC bound to `127.0.0.1` and access it through SSH, WireGuard, Tailscale or another trusted tunnel.

Classic VNC authentication effectively uses only the first eight password characters, so the tunnel/VPN should be treated as the primary security boundary.

## Vesktop

Vesktop is a third-party Discord client by the Vencord project with Vencord integrated. Its use may be subject to Discord's terms and the Vesktop/Vencord projects' own support guidance.
