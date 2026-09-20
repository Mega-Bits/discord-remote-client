FROM debian:bookworm-slim

ARG VESKTOP_VERSION=1.6.7
ARG VESKTOP_SHA256=0204a3fcf8861d11debf72a9be70423d2dca6d4698766b6fda7cfe39beea6a61

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/discord
ENV XDG_SESSION_TYPE=x11
ENV ELECTRON_OZONE_PLATFORM_HINT=x11
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV GALLIUM_DRIVER=llvmpipe

RUN echo "deb http://deb.debian.org/debian bookworm-backports main" \
      > /etc/apt/sources.list.d/bookworm-backports.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dbus \
    dbus-x11 \
    xauth \
    x11-utils \
    xdg-utils \
    xrdp \
    xorgxrdp \
    xserver-xorg-core \
    openbox \
    wmctrl \
    tini \
    procps \
    passwd \
    chromium \
    pipewire \
    pipewire-bin \
    pipewire-pulse \
    wireplumber \
    pulseaudio-utils \
    libgl1-mesa-dri \
    libegl-mesa0 \
    mesa-utils \
    libpulse0 \
    libasound2 \
    libsecret-1-0 \
    fonts-liberation \
    fonts-noto-color-emoji \
    tzdata \
    && apt-get install -y -t bookworm-backports --no-install-recommends \
    pipewire-module-xrdp \
    libpipewire-0.3-modules-xrdp \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 --shell /bin/bash discord

RUN set -eux; \
    curl -fL \
      "https://github.com/Vencord/Vesktop/releases/download/v${VESKTOP_VERSION}/vesktop_${VESKTOP_VERSION}_amd64.deb" \
      -o /tmp/vesktop.deb; \
    echo "${VESKTOP_SHA256}  /tmp/vesktop.deb" | sha256sum -c -; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/vesktop.deb; \
    rm -f /tmp/vesktop.deb; \
    command -v vesktop; \
    command -v chromium; \
    VESKTOP_BIN="$(readlink -f "$(command -v vesktop)")"; \
    echo "Checking Vesktop runtime libraries: $VESKTOP_BIN"; \
    ldd "$VESKTOP_BIN"; \
    if ldd "$VESKTOP_BIN" | grep -q "not found"; then \
      echo "Vesktop has unresolved shared-library dependencies."; \
      exit 1; \
    fi; \
    test -x /usr/libexec/pipewire-module-xrdp/load_pw_modules.sh; \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY startwm.sh /etc/xrdp/startwm.sh

RUN chown root:root /usr/local/bin/entrypoint.sh /etc/xrdp/startwm.sh \
    && chmod 755 /usr/local/bin/entrypoint.sh /etc/xrdp/startwm.sh

EXPOSE 3389

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
