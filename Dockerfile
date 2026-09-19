FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/discord
ENV DISPLAY=:1
ENV VENCORD_USER_DATA_DIR=/home/discord/.config/Vencord

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dbus \
    dbus-x11 \
    xauth \
    x11-utils \
    tigervnc-standalone-server \
    tigervnc-tools \
    openbox \
    wmctrl \
    gosu \
    tini \
    procps \
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
    command -v discord; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl -fL \
      "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux" \
      -o /usr/local/bin/vencord-installer; \
    chmod 755 /usr/local/bin/vencord-installer

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chown root:root /usr/local/bin/entrypoint.sh \
    && chmod 755 /usr/local/bin/entrypoint.sh

EXPOSE 5900

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
