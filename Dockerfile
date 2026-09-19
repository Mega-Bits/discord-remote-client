FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/discord
ENV DISPLAY=:1
ENV VENCORD_USER_DATA_DIR=/opt/vencord

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dbus \
    dbus-x11 \
    xauth \
    xvfb \
    x11vnc \
    openbox \
    gosu \
    tini \
    fonts-liberation \
    fonts-noto-color-emoji \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 --shell /bin/bash discord

RUN set -eux; \
    curl -fL "https://discord.com/api/download?platform=linux&format=deb" \
      -o /tmp/discord.deb; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/discord.deb; \
    rm -f /tmp/discord.deb; \
    DISCORD_BIN="$(command -v discord || true)"; \
    if [ -z "$DISCORD_BIN" ]; then \
      echo "Discord executable was not installed"; \
      dpkg -L discord || true; \
      exit 1; \
    fi; \
    test -x "$DISCORD_BIN"; \
    echo "Discord launcher: $DISCORD_BIN"; \
    echo "Discord launcher target: $(readlink -f "$DISCORD_BIN")"; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    DISCORD_BIN="$(command -v discord || true)"; \
    test -n "$DISCORD_BIN"; \
    test -x "$DISCORD_BIN"; \
    DISCORD_DIR="$(dpkg -L discord | while IFS= read -r path; do \
      if [ -d "$path/resources" ]; then \
        printf '%s\n' "$path"; \
        break; \
      fi; \
    done)"; \
    if [ -z "$DISCORD_DIR" ]; then \
      echo "Could not determine Discord installation directory"; \
      echo "Discord package contents:"; \
      dpkg -L discord || true; \
      exit 1; \
    fi; \
    echo "Discord install directory: $DISCORD_DIR"; \
    mkdir -p /opt/vencord; \
    curl -fL \
      "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux" \
      -o /tmp/vencord-installer; \
    chmod 755 /tmp/vencord-installer; \
    SUDO_USER=discord \
    HOME=/home/discord \
    VENCORD_USER_DATA_DIR=/opt/vencord \
      /tmp/vencord-installer --install --location "$DISCORD_DIR"; \
    chown -R discord:discord /opt/vencord; \
    rm -f /tmp/vencord-installer

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chown root:root /usr/local/bin/entrypoint.sh \
    && chmod 755 /usr/local/bin/entrypoint.sh

EXPOSE 5900

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
