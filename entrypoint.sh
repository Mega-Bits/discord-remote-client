#!/bin/bash
set -euo pipefail

export HOME=/home/discord
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-discord
export VENCORD_USER_DATA_DIR=/home/discord/.config/Vencord

SCREEN_WIDTH="${SCREEN_WIDTH:-1600}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-900}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
DISCORD_BOOTSTRAP_TIMEOUT="${DISCORD_BOOTSTRAP_TIMEOUT:-300}"

if [ "$(id -u)" = "0" ]; then
    echo "Preparing Discord container..."

    mkdir -p /home/discord/.config /home/discord/.vnc
    chown -R discord:discord /home/discord

    mkdir -p /tmp/.X11-unix
    chown root:root /tmp/.X11-unix
    chmod 1777 /tmp/.X11-unix
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

    mkdir -p "$XDG_RUNTIME_DIR"
    chown discord:discord "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"

    mkdir -p /run/dbus
    if [ ! -S /run/dbus/system_bus_socket ]; then
        echo "Starting system DBus..."
        dbus-daemon --system --fork
    fi

    exec gosu discord /bin/bash "$0" "$@"
fi

find_discord_app_asar() {
    find "$HOME/.config/discord" \
        -maxdepth 3 \
        -type f \
        -path "$HOME/.config/discord/app-*/resources/app.asar" \
        -print 2>/dev/null \
        | sort -V \
        | tail -n 1
}

stop_discord() {
    pkill -TERM -u "$(id -u)" -f '/usr/bin/discord|/home/discord/.config/discord/app-' 2>/dev/null || true
    sleep 2
    pkill -KILL -u "$(id -u)" -f '/usr/bin/discord|/home/discord/.config/discord/app-' 2>/dev/null || true
}

mkdir -p "$HOME/.vnc" "$VENCORD_USER_DATA_DIR"

echo "Starting virtual display..."
Xvfb :1 \
    -screen 0 "${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}" \
    -ac \
    +extension GLX \
    +render \
    -noreset &

sleep 2

echo "Starting Openbox..."
openbox --sm-disable &

sleep 1

echo "Creating VNC credentials..."
x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null
chmod 600 "$HOME/.vnc/passwd"

echo "Starting VNC server on port 5900..."
x11vnc \
    -display :1 \
    -forever \
    -shared \
    -repeat \
    -noxdamage \
    -nowf \
    -xkb \
    -rfbport 5900 \
    -rfbauth "$HOME/.vnc/passwd" &

sleep 2

APP_ASAR="$(find_discord_app_asar || true)"

if [ -z "$APP_ASAR" ]; then
    echo "Discord application files are not initialized yet. Bootstrapping Discord..."
    : > /tmp/discord-bootstrap.log

    dbus-run-session -- /usr/bin/discord --no-sandbox --disable-gpu \
        > /tmp/discord-bootstrap.log 2>&1 &

    for ((i = 0; i < DISCORD_BOOTSTRAP_TIMEOUT; i++)); do
        APP_ASAR="$(find_discord_app_asar || true)"
        if [ -n "$APP_ASAR" ]; then
            break
        fi
        sleep 1
    done

    if [ -z "$APP_ASAR" ]; then
        echo "Discord did not finish bootstrapping within ${DISCORD_BOOTSTRAP_TIMEOUT}s."
        echo "Bootstrap log:"
        cat /tmp/discord-bootstrap.log || true
        exit 1
    fi

    echo "Discord application downloaded: $APP_ASAR"
    stop_discord
fi

RESOURCES_DIR="$(dirname "$APP_ASAR")"

if [ ! -f "$RESOURCES_DIR/_app.asar" ]; then
    echo "Installing Vencord into $HOME/.config/discord..."
    /usr/local/bin/vencord-installer \
        --install \
        --location "$HOME/.config/discord"
else
    echo "Vencord is already installed for the current Discord application."
fi

echo "Starting Discord..."
exec dbus-run-session -- /usr/bin/discord \
    --no-sandbox \
    --disable-gpu
