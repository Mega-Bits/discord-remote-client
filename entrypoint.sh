#!/bin/bash
set -euo pipefail

export HOME=/home/discord
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-discord
export XDG_SESSION_TYPE=x11
export ELECTRON_OZONE_PLATFORM_HINT=x11
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
unset WAYLAND_DISPLAY

SCREEN_WIDTH="${SCREEN_WIDTH:-1920}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-1080}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
VNC_FRAME_RATE="${VNC_FRAME_RATE:-60}"
VESKTOP_RESTART_DELAY="${VESKTOP_RESTART_DELAY:-2}"

VESKTOP_FLAGS=(
    --no-sandbox
    --ozone-platform=x11
    --use-gl=angle
    --use-angle=swiftshader
    --enable-unsafe-swiftshader
    --disable-renderer-backgrounding
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
)

if [ "$(id -u)" = "0" ]; then
    echo "Preparing Vesktop container..."

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
    echo "Stopping Vesktop remote client..."
    pkill -TERM -u "$(id -u)" -f '/usr/bin/vesktop|/opt/Vesktop/vesktop|vesktop' 2>/dev/null || true
    [ -z "$MAXIMIZER_PID" ] || kill "$MAXIMIZER_PID" 2>/dev/null || true
    [ -z "$OPENBOX_PID" ] || kill "$OPENBOX_PID" 2>/dev/null || true
    [ -z "$VNC_PID" ] || kill "$VNC_PID" 2>/dev/null || true
}
trap cleanup TERM INT EXIT

maximize_vesktop_forever() {
    while true; do
        while read -r window_id; do
            [ -n "$window_id" ] || continue
            wmctrl -i -r "$window_id" -b add,maximized_vert,maximized_horz 2>/dev/null || true
        done < <(wmctrl -lx 2>/dev/null | awk 'tolower($0) ~ /vesktop|discord/ {print $1}')
        sleep 2
    done
}

mkdir -p "$HOME/.vnc"

echo "Creating VNC credentials..."
printf '%s\n' "$VNC_PASSWORD" | tigervncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

echo "Starting TigerVNC desktop on port 5900..."
Xtigervnc :1 \
    -geometry "${SCREEN_WIDTH}x${SCREEN_HEIGHT}" \
    -depth "$SCREEN_DEPTH" \
    -rfbport 5900 \
    -SecurityTypes VncAuth \
    -PasswordFile "$HOME/.vnc/passwd" \
    -AlwaysShared \
    -AcceptSetDesktopSize \
    -FrameRate "$VNC_FRAME_RATE" \
    -localhost no \
    -nolisten tcp \
    -desktop "Vesktop Remote Client" &
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

maximize_vesktop_forever &
MAXIMIZER_PID=$!

sleep 1

echo "Starting supervised Vesktop session with SwiftShader CPU rendering..."

while true; do
    set +e
    dbus-run-session -- /usr/bin/vesktop "${VESKTOP_FLAGS[@]}"
    EXIT_CODE=$?
    set -e

    echo "Vesktop exited with code $EXIT_CODE. Restarting in ${VESKTOP_RESTART_DELAY}s..."
    sleep "$VESKTOP_RESTART_DELAY"
done
