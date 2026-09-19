#!/bin/bash
set -euo pipefail

export HOME=/home/discord
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-discord
export VENCORD_USER_DATA_DIR=/home/discord/.config/Vencord
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

SCREEN_WIDTH="${SCREEN_WIDTH:-1920}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-1080}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
VNC_FRAME_RATE="${VNC_FRAME_RATE:-60}"
DISCORD_BOOTSTRAP_TIMEOUT="${DISCORD_BOOTSTRAP_TIMEOUT:-300}"
DISCORD_RESTART_DELAY="${DISCORD_RESTART_DELAY:-2}"

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

    echo "Starting system DBus..."
    mkdir -p /run/dbus
    rm -f /run/dbus/system_bus_socket /run/dbus/pid
    dbus-daemon --system --fork

    exec gosu discord /bin/bash "$0" "$@"
fi

VNC_PID=""
OPENBOX_PID=""
MAXIMIZER_PID=""

cleanup() {
    trap - TERM INT
    echo "Stopping Discord remote client..."

    pkill -TERM -u "$(id -u)" -f '/usr/bin/discord|/home/discord/.config/discord/app-' 2>/dev/null || true

    [ -z "$MAXIMIZER_PID" ] || kill "$MAXIMIZER_PID" 2>/dev/null || true
    [ -z "$OPENBOX_PID" ] || kill "$OPENBOX_PID" 2>/dev/null || true
    [ -z "$VNC_PID" ] || kill "$VNC_PID" 2>/dev/null || true
}
trap cleanup TERM INT EXIT

find_discord_app_asar() {
    find "$HOME/.config/discord"         -maxdepth 4         -type f         -path "$HOME/.config/discord/app-*/resources/app.asar"         -print 2>/dev/null         | sort -V         | tail -n 1
}

stop_discord() {
    pkill -TERM -u "$(id -u)" -f '/usr/bin/discord|/home/discord/.config/discord/app-' 2>/dev/null || true

    for _ in $(seq 1 10); do
        if ! pgrep -u "$(id -u)" -f '/usr/bin/discord|/home/discord/.config/discord/app-' >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    pkill -KILL -u "$(id -u)" -f '/usr/bin/discord|/home/discord/.config/discord/app-' 2>/dev/null || true
}

wait_for_discord_app() {
    local elapsed=0
    local stable=0
    local previous_path=""
    local previous_size=""
    local app_asar=""
    local size=""

    while [ "$elapsed" -lt "$DISCORD_BOOTSTRAP_TIMEOUT" ]; do
        app_asar="$(find_discord_app_asar || true)"

        if [ -n "$app_asar" ] && [ -s "$app_asar" ]; then
            size="$(stat -c '%s' "$app_asar" 2>/dev/null || true)"

            if [ "$app_asar" = "$previous_path" ] && [ -n "$size" ] && [ "$size" = "$previous_size" ]; then
                stable=$((stable + 1))
            else
                stable=0
                previous_path="$app_asar"
                previous_size="$size"
            fi

            if [ "$stable" -ge 3 ]; then
                echo "Discord application is ready: $app_asar"
                return 0
            fi
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 1
}

ensure_vencord() {
    local app_asar
    local resources

    app_asar="$(find_discord_app_asar || true)"

    if [ -z "$app_asar" ] || [ ! -s "$app_asar" ]; then
        echo "Discord app.asar is not available yet."
        return 1
    fi

    resources="$(dirname "$app_asar")"

    if [ -s "$resources/_app.asar" ]; then
        echo "Vencord is installed in $resources."
        return 0
    fi

    echo "Installing Vencord into $HOME/.config/discord..."
    /usr/local/bin/vencord-installer         --install         --location "$HOME/.config/discord"

    if [ ! -s "$resources/_app.asar" ]; then
        echo "Vencord installer completed, but _app.asar was not created."
        return 1
    fi

    echo "Vencord patch verified: $resources/_app.asar"
}

maximize_discord_forever() {
    while true; do
        while read -r window_id; do
            [ -n "$window_id" ] || continue
            wmctrl -i -r "$window_id" -b add,maximized_vert,maximized_horz 2>/dev/null || true
        done < <(wmctrl -lx 2>/dev/null | awk 'tolower($0) ~ /discord/ {print $1}')

        sleep 2
    done
}

mkdir -p "$HOME/.vnc" "$VENCORD_USER_DATA_DIR"

echo "Creating VNC credentials..."
printf '%s
' "$VNC_PASSWORD" | tigervncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

echo "Starting TigerVNC desktop on port 5900..."
Xtigervnc :1     -geometry "${SCREEN_WIDTH}x${SCREEN_HEIGHT}"     -depth "$SCREEN_DEPTH"     -rfbport 5900     -SecurityTypes VncAuth     -PasswordFile "$HOME/.vnc/passwd"     -AlwaysShared     -AcceptSetDesktopSize     -FrameRate "$VNC_FRAME_RATE"     -localhost no     -nolisten tcp     -desktop "Discord Remote Client" &
VNC_PID=$!

for _ in $(seq 1 30); do
    if DISPLAY=:1 xdpyinfo >/dev/null 2>&1; then
        break
    fi

    if ! kill -0 "$VNC_PID" 2>/dev/null; then
        echo "TigerVNC exited before the X display became ready."
        wait "$VNC_PID" || true
        exit 1
    fi

    sleep 1
done

if ! DISPLAY=:1 xdpyinfo >/dev/null 2>&1; then
    echo "TigerVNC X display did not become ready."
    exit 1
fi

echo "Software renderer:"
glxinfo -B 2>/dev/null | grep -E 'OpenGL vendor|OpenGL renderer|OpenGL version' || true

echo "Starting Openbox..."
openbox --sm-disable &
OPENBOX_PID=$!

maximize_discord_forever &
MAXIMIZER_PID=$!

sleep 1

APP_ASAR="$(find_discord_app_asar || true)"

if [ -z "$APP_ASAR" ] || [ ! -s "$APP_ASAR" ]; then
    echo "First start: letting Discord bootstrap its application files..."
    : > /tmp/discord-bootstrap.log

    dbus-run-session -- /usr/bin/discord --no-sandbox         > /tmp/discord-bootstrap.log 2>&1 &

    if ! wait_for_discord_app; then
        echo "Discord did not produce a stable app.asar within ${DISCORD_BOOTSTRAP_TIMEOUT}s."
        echo "Bootstrap log:"
        cat /tmp/discord-bootstrap.log || true
        exit 1
    fi

    echo "Discord bootstrap complete. Stopping bootstrap instance before Vencord patch..."
    stop_discord
    sleep 2
fi

if ! ensure_vencord; then
    echo "Vencord installation failed."
    exit 1
fi

echo "Starting supervised Discord session..."

while true; do
    if ! ensure_vencord; then
        echo "Vencord verification failed; retrying in ${DISCORD_RESTART_DELAY}s..."
        sleep "$DISCORD_RESTART_DELAY"
        continue
    fi

    set +e
    dbus-run-session -- /usr/bin/discord --no-sandbox
    EXIT_CODE=$?
    set -e

    echo "Discord exited with code $EXIT_CODE. Restarting in ${DISCORD_RESTART_DELAY}s..."
    sleep "$DISCORD_RESTART_DELAY"
done
