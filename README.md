# Discord Remote Client

Docker image for running **Vesktop** plus a dedicated **Chromium music browser** in the same RDP desktop.

## What it does

- Vesktop with built-in Vencord
- Chromium in the same container / RDP desktop
- YouTube/browser audio is routed to an internal `music_bus`
- The music bus and the redirected RDP microphone are mixed into a virtual Discord microphone
- Discord/Vesktop output is sent back to the RDP client
- Optional local monitoring of browser music
- xrdp + xorgxrdp dynamic desktop resizing
- PipeWire audio routing
- CPU-only rendering with SwiftShader / Mesa llvmpipe

## Audio graph

```text
Chromium / YouTube
        |
        v
    music_bus -------------------+
        |                        |
        |                        v
        |                  discord_mix
        |                        |
        |                        v
        +----> xrdp-sink   discord_mix.monitor
                 ^                |
                 |                v
            Vesktop out      Vesktop mic
                 ^
                 |
             Discord

Local/RDP microphone
        |
        v
   xrdp-source
        |
        +--------------------> discord_mix
```

The important separation is that Chromium is launched with `PULSE_SINK=music_bus`, so browser audio does not get confused with Discord playback.

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

RDP is bound to:

```text
127.0.0.1:3389
```

Use an SSH tunnel, VPN, Tailscale or another trusted path.

## Remote Desktop Manager

Create an **RDP** entry:

```text
Host: 127.0.0.1
Port: 3389
Username: discord
Password: RDP_PASSWORD
```

Enable remote audio playback and microphone/audio-recording redirection if you also want to speak through your local microphone.

Both Vesktop and Chromium start automatically in the RDP session. Chromium opens YouTube by default.

## Vesktop devices

The container forces these devices for Vesktop:

```text
Output: xrdp-sink
Input:  discord_mix.monitor
```

So Discord receives the internal mixed signal rather than raw browser/system audio.

## Browser music

Chromium is launched with:

```text
PULSE_SINK=music_bus
```

Anything played in this dedicated Chromium instance goes to the internal music bus and can be transmitted as the Discord microphone input.

By default, the music is also monitored through `xrdp-sink`, so you can hear what is currently being sent.

## Audio routing switches

| Variable | Default | Meaning |
| --- | --- | --- |
| `MUSIC_TO_DISCORD` | `1` | Browser/YouTube is included in the Discord microphone mix |
| `MIC_TO_DISCORD` | `1` | Your redirected RDP microphone is included in the Discord microphone mix |
| `MONITOR_MUSIC` | `1` | Browser music is also played back to you through RDP |
| `MUSIC_BROWSER_URL` | `https://www.youtube.com/` | URL opened by the dedicated Chromium browser |
| `VESKTOP_RESTART_DELAY` | `2` | Vesktop restart delay |
| `CHROMIUM_RESTART_DELAY` | `2` | Chromium restart delay |

For a pure music-account setup without your local microphone:

```env
MIC_TO_DISCORD=0
MUSIC_TO_DISCORD=1
MONITOR_MUSIC=1
```

For music plus talking:

```env
MIC_TO_DISCORD=1
MUSIC_TO_DISCORD=1
MONITOR_MUSIC=1
```

## Persistence

```text
/home/discord/.config
```

is persisted in the `discord_config` volume. This stores Vesktop/Vencord state, Discord login data and the dedicated Chromium profile.

## CPU-only rendering

No physical GPU is required. Vesktop and Chromium use SwiftShader while Mesa llvmpipe is available for the X11 session.

## Security

Keep RDP bound to `127.0.0.1` and reach it only through a trusted tunnel or VPN.

## Notes

Vesktop/Vencord are third-party Discord software. Automated or music-oriented use can be subject to Discord's terms and server rules.
