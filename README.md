# Discord Remote Client

Lightweight Docker image for running the official Discord Linux client with Vencord on a virtual X11 desktop and controlling it remotely over VNC.

## Included

- Pinned Discord Linux client package
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

## GitHub Actions build configuration

The Docker build intentionally does not use Discord's moving Linux download endpoint. Configure these repository Actions secrets before running the workflow:

| Secret | Description |
| --- | --- |
| `DISCORD_DEB_URL` | URL of a pinned Discord `.deb` artifact known to be compatible with Vencord |
| `DISCORD_DEB_SHA256` | SHA256 checksum of that exact `.deb` file |

The image build validates the checksum before installing the package and then verifies that the installed Discord package contains a `resources/app.asar` file before applying Vencord.

If either secret is missing, the build fails intentionally instead of silently pulling a different Discord package.

For a local build, pass the same values as build arguments:

```bash
docker build \
  --build-arg DISCORD_DEB_URL="https://example.invalid/discord.deb" \
  --build-arg DISCORD_DEB_SHA256="<sha256>" \
  -t discord-remote-client .
```

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

## Updating Discord

Discord is pinned at build time. To update it:

1. Choose the new Discord `.deb` artifact.
2. Verify that it is compatible with Vencord.
3. Update `DISCORD_DEB_URL` and `DISCORD_DEB_SHA256` in the repository Actions secrets.
4. Run the Docker workflow again.

The build will reject a package whose checksum does not match or which does not expose the expected `resources/app.asar` layout.

## Updating the container

After a successful image build:

```bash
docker compose pull
docker compose up -d
```

## Security

VNC authentication is not a substitute for transport encryption. Keep port 5900 bound to localhost and access it through SSH, WireGuard, Tailscale, or another trusted private network.

## Vencord

Vencord is a third-party Discord client modification. Its use may be subject to Discord's terms and Vencord's own support guidance.
