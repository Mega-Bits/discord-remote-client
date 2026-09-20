#!/bin/bash
set -euo pipefail

export HOME=/home/discord
export USER=discord
export LOGNAME=discord
export XDG_SESSION_TYPE=x11
export ELECTRON_OZONE_PLATFORM_HINT=x11
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
unset WAYLAND_DISPLAY

VESKTOP_RESTART_DELAY="${VESKTOP_RESTART_DELAY:-2}"

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    exec dbus-run-session -- "$0"
fi

display_id="$(printf '%s' "${DISPLAY:-rdp}" | tr -cd '0-9' | head -c 8)"
[ -n "$display_id" ] || display_id="rdp"

export XDG_RUNTIME_DIR="/tmp/runtime-discord-${display_id}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

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

PIPEWIRE_PID=""
PULSE_PID=""
WIREPLUMBER_PID=""
OPENBOX_PID=""
MAXIMIZER_PID=""

cleanup_session() {
    trap - TERM INT
    pkill -TERM -u "$(id -u)" -f '/usr/bin/vesktop|/opt/Vesktop/vesktop|vesktop' 2>/dev/null || true
    [ -z "$MAXIMIZER_PID" ] || kill "$MAXIMIZER_PID" 2>/dev/null || true
    [ -z "$OPENBOX_PID" ] || kill "$OPENBOX_PID" 2>/dev/null || true
    [ -z "$WIREPLUMBER_PID" ] || kill "$WIREPLUMBER_PID" 2>/dev/null || true
    [ -z "$PULSE_PID" ] || kill "$PULSE_PID" 2>/dev/null || true
    [ -z "$PIPEWIRE_PID" ] || kill "$PIPEWIRE_PID" 2>/dev/null || true
}
trap cleanup_session EXIT TERM INT

echo "Starting PipeWire for RDP audio..."
pipewire >"$XDG_RUNTIME_DIR/pipewire.log" 2>&1 &
PIPEWIRE_PID=$!

pipewire-pulse >"$XDG_RUNTIME_DIR/pipewire-pulse.log" 2>&1 &
PULSE_PID=$!

wireplumber >"$XDG_RUNTIME_DIR/wireplumber.log" 2>&1 &
WIREPLUMBER_PID=$!

audio_ready=0
for _ in $(seq 1 30); do
    if pactl info >/dev/null 2>&1; then
        audio_ready=1
        break
    fi
    sleep 1
done

if [ "$audio_ready" -eq 1 ]; then
    echo "Loading xrdp PipeWire audio sink/source..."
    /usr/libexec/pipewire-module-xrdp/load_pw_modules.sh -l 2 || true

    echo "RDP audio devices:"
    pactl list short sinks || true
    pactl list short sources || true
else
    echo "PipeWire Pulse compatibility layer did not become ready."
fi

echo "Starting Openbox..."
openbox --sm-disable &
OPENBOX_PID=$!

maximize_vesktop_forever() {
    while true; do
        while read -r window_id; do
            [ -n "$window_id" ] || continue
            wmctrl -i -r "$window_id" -b add,maximized_vert,maximized_horz 2>/dev/null || true
        done < <(wmctrl -lx 2>/dev/null | awk 'tolower($0) ~ /vesktop|discord/ {print $1}')
        sleep 2
    done
}

maximize_vesktop_forever &
MAXIMIZER_PID=$!

sleep 1

echo "Starting supervised Vesktop session with RDP + SwiftShader CPU rendering..."

while true; do
    set +e
    /usr/bin/vesktop "${VESKTOP_FLAGS[@]}"
    EXIT_CODE=$?
    set -e

    echo "Vesktop exited with code $EXIT_CODE. Restarting in ${VESKTOP_RESTART_DELAY}s..."
    sleep "$VESKTOP_RESTART_DELAY"
done
