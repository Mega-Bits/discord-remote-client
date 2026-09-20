FROM debian:bookworm-slim AS pulseaudio-xrdp-builder

ARG PULSEAUDIO_XRDP_REF=c27d5395a15b75dd2cd199b6938d4994e6f173fb
ENV DEBIAN_FRONTEND=noninteractive

RUN printf '%s\n' \
    'deb-src http://deb.debian.org/debian bookworm main' \
    'deb-src http://deb.debian.org/debian bookworm-updates main' \
    'deb-src http://deb.debian.org/debian-security bookworm-security main' \
    > /etc/apt/sources.list.d/debian-src.list

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      build-essential \
      autoconf \
      automake \
      libtool \
      pkg-config \
      dpkg-dev \
      meson \
      ninja-build \
      libpulse-dev \
      pulseaudio; \
    apt-get build-dep -y pulseaudio; \
    mkdir -p /build; \
    cd /build; \
    apt-get source pulseaudio; \
    PULSE_DIR="$(find /build -mindepth 1 -maxdepth 1 -type d -name 'pulseaudio-*' | head -n 1)"; \
    test -n "$PULSE_DIR"; \
    cd "$PULSE_DIR"; \
    meson setup build; \
    git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git /build/pulseaudio-module-xrdp; \
    cd /build/pulseaudio-module-xrdp; \
    git checkout "$PULSEAUDIO_XRDP_REF"; \
    ./bootstrap; \
    PULSE_DIR="$PULSE_DIR" PULSE_CONFIG_DIR="$PULSE_DIR/build" ./configure; \
    make -j"$(nproc)"; \
    make install DESTDIR=/out

FROM debian:bookworm-slim

ARG VESKTOP_VERSION=1.6.7
ARG VESKTOP_SHA256=0204a3fcf8861d11debf72a9be70423d2dca6d4698766b6fda7cfe39beea6a61

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/discord
ENV VENCORD_USER_DATA_DIR=/home/discord/.config/vesktop
ENV XDG_SESSION_TYPE=x11
ENV ELECTRON_OZONE_PLATFORM_HINT=x11
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV GALLIUM_DRIVER=llvmpipe

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
    pulseaudio \
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
    && rm -rf /var/lib/apt/lists/*

COPY --from=pulseaudio-xrdp-builder /out/ /

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
    VESKTOP_BIN="$(readlink -f "$(command -v vesktop)")"; \
    echo "Checking Vesktop runtime libraries: $VESKTOP_BIN"; \
    ldd "$VESKTOP_BIN"; \
    if ldd "$VESKTOP_BIN" | grep -q "not found"; then \
      echo "Vesktop has unresolved shared-library dependencies."; \
      exit 1; \
    fi; \
    test -x /usr/libexec/pulseaudio-module-xrdp/load_pa_modules.sh; \
    find /usr/lib -name 'module-xrdp-sink.so' -o -name 'module-xrdp-source.so'; \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY startwm.sh /etc/xrdp/startwm.sh

RUN chown root:root /usr/local/bin/entrypoint.sh /etc/xrdp/startwm.sh \
    && chmod 755 /usr/local/bin/entrypoint.sh /etc/xrdp/startwm.sh

EXPOSE 3389

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
