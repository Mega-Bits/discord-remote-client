# Discord Remote Client

Docker image for running **Vesktop** with its built-in Vencord integration in an RDP-accessible Linux desktop with two-way audio.

## Stack

- Vesktop 1.6.7
- Built-in Vencord integration
- xrdp + xorgxrdp
- PipeWire + pipewire-module-xrdp
- RDP speaker redirection
- RDP microphone redirection
- Openbox
- SwiftShader CPU rendering for Electron
- Mesa llvmpipe
- DBus
- Persistent user configuration
- GitHub Actions image build for GHCR

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

Then deploy:

```bash
docker compose pull
docker compose up -d --force-recreate
```

The Compose file binds RDP only to the Docker host loopback interface:

```text
127.0.0.1:3389
```

Use an SSH tunnel, VPN, Tailscale or another trusted path from Remote Desktop Manager to the Docker host.

## Remote Desktop Manager

Create an **RDP** entry rather than a VNC entry.

Connection:

```text
Host: 127.0.0.1
Port: 3389
Username: discord
Password: value of RDP_PASSWORD
```

Enable RDP remote audio so sound is played on the local computer, and enable audio recording / microphone redirection so the local recording device is exposed to the remote session.

xrdp uses the standard RDP audio output and input channels. The PipeWire xrdp module creates:

```text
xrdp-sink    -> Vesktop/Discord playback back to the RDP client
xrdp-source  -> RDP client microphone/recording device into Vesktop
```

Vesktop should use those as its speaker and microphone devices.

## Music / virtual audio cable

For a music-only virtual microphone on Windows:

1. Set the browser output device to **CABLE Input (VB-Audio Virtual Cable)**.
2. Use **CABLE Output** as the recording device redirected by the RDP client.
3. Select the xrdp microphone/source in Vesktop.

For simultaneous voice + browser music, use **Voicemeeter**:

1. Real microphone -> Voicemeeter hardware input.
2. Browser / VB-Cable output -> another Voicemeeter input.
3. Route both inputs to a virtual bus such as **B1**.
4. Redirect the Voicemeeter B1 output as the RDP microphone.
5. Vesktop receives the mixed signal through `xrdp-source`.

This lets the remote Vesktop account behave like a music source while you can still talk over the same Discord voice connection.

## Persistence

The complete user configuration directory is stored in the `discord_config` volume:

```text
/home/discord/.config
```

That includes Vesktop settings, Vencord settings and the Discord web session/login state.

## Dynamic resolution

xorgxrdp uses the RDP desktop session directly, so Remote Desktop Manager can resize the remote desktop through the normal RDP display controls.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `Europe/Berlin` | Container timezone |
| `RDP_PASSWORD` | `changeme` | Password for the `discord` RDP user |
| `VESKTOP_RESTART_DELAY` | `2` | Delay before Vesktop is restarted after closing |

## CPU-only rendering

No physical GPU is required. Vesktop/Electron is launched through SwiftShader:

```text
--use-gl=angle
--use-angle=swiftshader
--enable-unsafe-swiftshader
```

Mesa llvmpipe is also available for the X11 session.

## Security

RDP is bound to `127.0.0.1` by default. Keep it behind SSH, WireGuard, Tailscale or another trusted tunnel rather than exposing port 3389 directly to the Internet.

## Vesktop

Vesktop is a third-party Discord client by the Vencord project with Vencord integrated. Its use may be subject to Discord's terms and the Vesktop/Vencord projects' support guidance.
