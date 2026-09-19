FROM debian:bookworm-slim

ARG DISCORD_DEB_URL
ARG DISCORD_DEB_SHA256

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
    test -n "$DISCORD_DEB_URL"; \
    test -n "$DISCORD_DEB_SHA256"; \
    curl -fL "$DISCORD_DEB_URL" -o /tmp/discord.deb; \
    echo "$DISCORD_DEB_SHA256  /tmp/discord.deb" | sha256sum -c -; \
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
    DISCORD_BIN="$(command -v discord)"; \
    test -x "$DISCORD_BIN"; \
    DISCORD_TARGET="$(readlink -f "$DISCORD_BIN")"; \
    DISCORD_DIR="$(dirname "$DISCORD_TARGET")"; \
    APP_ASAR=""; \
    for candidate in \
      "$DISCORD_DIR/resources/app.asar" \
      "/usr/share/discord/resources/app.asar" \
      "/opt/discord/resources/app.asar"; do \
      if [ -f "$candidate" ]; then \
        APP_ASAR="$candidate"; \
        break; \
      fi; \
    done; \
    if [ -z "$APP_ASAR" ]; then \
      APP_ASAR="$(find / -type f -path '*/resources/app.asar' \
        -print -quit 2>/dev/null || true)"; \
    fi; \
    if [ -z "$APP_ASAR" ]; then \
      echo "Discord package does not contain resources/app.asar"; \
      echo "Launcher: $DISCORD_BIN"; \
      echo "Target: $DISCORD_TARGET"; \
      echo "Discord package contents:"; \
      dpkg -L discord || true; \
      exit 1; \
    fi; \
    DISCORD_DIR="$(dirname "$(dirname "$APP_ASAR")")"; \
    echo "Discord app.asar: $APP_ASAR"; \
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
