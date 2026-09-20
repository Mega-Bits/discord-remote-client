FROM node:22-bookworm-slim AS vencord-build

ARG VENCORD_REF=59a54286542651fff5ea53f0ce6cadf2a6aa7521

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm@11.9.0

RUN git clone https://github.com/Vendicated/Vencord.git /src \
    && cd /src \
    && git checkout "$VENCORD_REF"

WORKDIR /src

# Headless/VNC workarounds:
# 1. Keep NoTrack, but disable only its Sentry-abort hook.
# 2. Load Discord's original preload before injecting Vencord's renderer.
#    Vanilla Discord reaches pageReady reliably, while the normal Vencord preload
#    path stalls before pageReady in this headless X11/TigerVNC environment.
RUN node <<'NODE'
const fs = require("fs");

{
    const path = "src/plugins/_core/noTrack.ts";
    let source = fs.readFileSync(path, "utf8");
    const pattern = /    start\(\) \{[\s\S]*?\n    \},\n\n    analyticsTrackingStoreMaker\(\) \{/;

    if (!pattern.test(source)) {
        throw new Error("Could not locate NoTrack.start() block");
    }

    source = source.replace(
        pattern,
        "    start() { },\n\n    analyticsTrackingStoreMaker() {"
    );

    fs.writeFileSync(path, source);
}

{
    const path = "src/preload.ts";
    let source = fs.readFileSync(path, "utf8");

    const oldBlock = `    if (IS_DISCORD_DESKTOP) {
        webFrame.executeJavaScript(sendSync<string>(IpcEvents.PRELOAD_GET_RENDERER_JS));
        // Not supported in sandboxed preload scripts but Discord doesn't support it either so who cares
        require(process.env.DISCORD_PRELOAD!);
    }`;

    const newBlock = `    if (IS_DISCORD_DESKTOP) {
        console.log("[Vencord Headless] Loading original Discord preload first");
        // Not supported in sandboxed preload scripts but Discord doesn't support it either so who cares
        require(process.env.DISCORD_PRELOAD!);
        console.log("[Vencord Headless] Original Discord preload loaded");

        webFrame.executeJavaScript(sendSync<string>(IpcEvents.PRELOAD_GET_RENDERER_JS));
        console.log("[Vencord Headless] Vencord renderer injection scheduled");
    }`;

    if (!source.includes(oldBlock)) {
        throw new Error("Could not locate Vencord preload injection block");
    }

    source = source.replace(oldBlock, newBlock);
    fs.writeFileSync(path, source);
}
NODE

RUN pnpm install --frozen-lockfile \
    && pnpm build \
    && printf '%s\n' "$VENCORD_REF-preload-first" > dist/HEADLESS_BUILD_REF


FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/discord
ENV DISPLAY=:1
ENV VENCORD_USER_DATA_DIR=/home/discord/.config/Vencord
ENV VENCORD_DEV_INSTALL=1
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
    tigervnc-standalone-server \
    tigervnc-tools \
    openbox \
    wmctrl \
    gosu \
    tini \
    procps \
    libgl1-mesa-dri \
    libegl-mesa0 \
    mesa-utils \
    libpulse0 \
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

COPY --from=vencord-build /src/dist /usr/local/share/vencord-dist
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chown -R root:root /usr/local/share/vencord-dist \
    && chown root:root /usr/local/bin/entrypoint.sh \
    && chmod 755 /usr/local/bin/entrypoint.sh

EXPOSE 5900

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
