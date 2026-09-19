#!/bin/bash
set -e

export HOME=/home/discord
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-discord

SCREEN_WIDTH="${SCREEN_WIDTH:-1600}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-900}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"

if [ "$(id -u)" = "0" ]; then
    echo "Preparing Discord container..."

    mkdir -p /home/discord/.config
    chown -R discord:discord /home/discord

    mkdir -p /tmp/.X11-unix
    chown root:root /tmp/.X11-unix
    chmod 1777 /tmp/.X11-unix

    rm -f /tmp/.X1-lock
    rm -f /tmp/.X11-unix/X1

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

mkdir -p "$HOME/.vnc"

echo "Starting virtual display..."
Xvfb :1     -screen 0 "${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}"     -ac     +extension GLX     +render     -noreset &

sleep 2

echo "Starting Openbox..."
openbox --sm-disable &

sleep 1

echo "Creating VNC credentials..."
x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null
chmod 600 "$HOME/.vnc/passwd"

echo "Starting VNC server on port 5900..."
x11vnc     -display :1     -forever     -shared     -repeat     -noxdamage     -nowf     -xkb     -rfbport 5900     -rfbauth "$HOME/.vnc/passwd" &

sleep 2

echo "Starting Discord + Vencord..."
exec dbus-run-session -- /usr/bin/discord     --no-sandbox     --disable-gpu
