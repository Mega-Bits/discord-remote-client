# Discord Remote Client

Lightweight Docker image for running **Vesktop** with its built-in Vencord integration over RDP.

## Stack

- Vesktop 1.6.7
- Built-in Vencord integration
- xrdp + xorgxrdp
- Openbox
- Native PulseAudio
- `pulseaudio-module-xrdp` for RDP speaker + microphone redirection
- CPU-only Electron compositor
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

The container uses **real PulseAudio**, not PipeWire's PulseAudio compatibility server. The official XRDP PulseAudio modules create:

```text
xrdp-sink    -> Discord/Vesktop sound to the RDP client
xrdp-source  -> RDP client's redirected microphone into Discord/Vesktop
```

The session sets both as defaults and explicitly unmutes them.

In Remote Desktop Manager, speaker playback and microphone recording redirection still need to be enabled for the RDP entry.

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

No physical GPU is required. Vesktop/Electron uses the CPU compositor path for the XRDP framebuffer.

For best responsiveness use a moderate RDP desktop size such as 1280x720, 1600x900 or 1920x1080.

## Security

Keep RDP bound to `127.0.0.1` and access it through SSH, WireGuard, Tailscale or another trusted tunnel.

## Vesktop

Vesktop is a third-party Discord client by the Vencord project with Vencord integrated.
