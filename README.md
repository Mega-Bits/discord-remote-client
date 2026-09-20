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
| `VESKTOP_RESTART_DELAY` | `2` | Delay before Vesktop restarts after closing |

## CPU-only rendering

No physical GPU is required. Vesktop/Electron uses SwiftShader and Mesa llvmpipe.

## Security

Keep RDP bound to `127.0.0.1` and access it through SSH, WireGuard, Tailscale or another trusted tunnel.

## Vesktop

Vesktop is a third-party Discord client by the Vencord project with Vencord integrated.
