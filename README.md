# Discord Remote Client

Lightweight Docker image for running **Vesktop** with its built-in Vencord integration over RDP.

## Stack

- Vesktop 1.6.7
- Built-in Vencord integration
- xrdp + xorgxrdp
- Openbox
- PipeWire xrdp audio support
- SwiftShader CPU rendering
- Mesa llvmpipe
- Persistent user configuration

The image is built for `linux/amd64`.

## Image

```text
ghcr.io/mega-bits/discord-remote-client:latest
```

## Deploy

Set an RDP password:

```env
RDP_PASSWORD=change-me-now
```

Then:

```bash
docker compose pull
docker compose up -d --force-recreate
```

RDP is bound to the Docker host loopback interface:

```text
127.0.0.1:3389
```

Use an SSH tunnel, VPN or another trusted path from Remote Desktop Manager.

## Remote Desktop Manager

Create an RDP entry:

```text
Host: 127.0.0.1
Port: 3389
Username: discord
Password: value of RDP_PASSWORD
```

Vesktop starts automatically inside the RDP session.

## Audio

The image keeps standard xrdp PipeWire audio support for normal RDP speaker and microphone redirection. There is no browser, virtual music bus, audio cable or custom mixer in the container.

## Persistence

The complete user configuration directory is stored in:

```text
/home/discord/.config
```

This includes Vesktop/Vencord settings and Discord login state.

## Dynamic resolution

xorgxrdp handles RDP desktop resizing directly.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `Europe/Berlin` | Container timezone |
| `RDP_PASSWORD` | `changeme` | Password for the `discord` RDP user |
| `RDP_MAX_BPP` | `16` | Maximum RDP color depth; 16 is optimized for CPU-only servers |
| `VESKTOP_RESTART_DELAY` | `2` | Delay before Vesktop restarts after closing |

## CPU-only rendering

No physical GPU is required. Vesktop/Electron is launched with GPU acceleration and the software GPU rasterizer disabled, forcing Chromium's CPU compositor path for the XRDP framebuffer.

For best responsiveness on a CPU-only host, use a moderate RDP desktop size such as 1280x720, 1600x900 or 1920x1080. Very large client windows increase the number of pixels XRDP and Electron must process in software.

## Security

Keep RDP bound to `127.0.0.1` and access it through SSH, WireGuard, Tailscale or another trusted tunnel.

## Vesktop

Vesktop is a third-party Discord client by the Vencord project with Vencord integrated.
