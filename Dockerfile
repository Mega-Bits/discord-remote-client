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
    apt-get install -y /tmp/discord.deb; \
    rm -f /tmp/discord.deb; \
    rm -rf /var/lib/apt/lists/*; \
    DISCORD_BIN="$(find -L /usr/share/discord \
      -maxdepth 3 \
      -type f \
      -perm /111 \
      \( -name Discord -o -name discord \) \
      -print -quit)"; \
    test -n "$DISCORD_BIN"; \
    echo "Discord executable: $DISCORD_BIN"

RUN set -eux; \
    DISCORD_BIN="$(find -L /usr/share/discord \
      -maxdepth 3 \
      -type f \
      -perm /111 \
      \( -name Discord -o -name discord \) \
      -print -quit)"; \
    test -n "$DISCORD_BIN"; \
    DISCORD_DIR="$(dirname "$DISCORD_BIN")"; \
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
