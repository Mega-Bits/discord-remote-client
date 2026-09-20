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

export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"
export PULSE_SERVER="unix:$PULSE_RUNTIME_PATH/native"

VESKTOP_FLAGS=(
    --no-sandbox
    --ozone-platform=x11
    --disable-gpu
    --disable-software-rasterizer
    --disable-gpu-compositing
    --disable-renderer-backgrounding
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
)

PULSE_PID=""
OPENBOX_PID=""
MAXIMIZER_PID=""

cleanup_session() {
    trap - TERM INT
    pkill -TERM -u "$(id -u)" -f '/usr/bin/vesktop|/opt/Vesktop/vesktop|vesktop' 2>/dev/null || true
    [ -z "$MAXIMIZER_PID" ] || kill "$MAXIMIZER_PID" 2>/dev/null || true
    [ -z "$OPENBOX_PID" ] || kill "$OPENBOX_PID" 2>/dev/null || true
    [ -z "$PULSE_PID" ] || kill "$PULSE_PID" 2>/dev/null || true
}
trap cleanup_session EXIT TERM INT

echo "Starting native PulseAudio for RDP audio..."
mkdir -p "$PULSE_RUNTIME_PATH"
pulseaudio \
    --daemonize=no \
    --exit-idle-time=-1 \
    --log-target=stderr \
    --log-level=notice \
    >"$XDG_RUNTIME_DIR/pulseaudio.log" 2>&1 &
PULSE_PID=$!

audio_ready=0
for _ in $(seq 1 30); do
    if pactl info >/dev/null 2>&1; then
        audio_ready=1
        break
    fi

    if ! kill -0 "$PULSE_PID" 2>/dev/null; then
        echo "PulseAudio exited before becoming ready."
        cat "$XDG_RUNTIME_DIR/pulseaudio.log" || true
        exit 1
    fi

    sleep 1
done

if [ "$audio_ready" -ne 1 ]; then
    echo "PulseAudio did not become ready."
    cat "$XDG_RUNTIME_DIR/pulseaudio.log" || true
    exit 1
fi

echo "Loading native PulseAudio XRDP sink/source..."
if ! /usr/libexec/pulseaudio-module-xrdp/load_pa_modules.sh; then
    echo "XRDP PulseAudio modules failed to load."
    cat "$XDG_RUNTIME_DIR/pulseaudio.log" || true
    pactl list short modules || true
    exit 1
fi

echo "RDP PulseAudio devices:"
pactl list short sinks || true
pactl list short sources || true

if ! pactl list short sinks | awk '{print $2}' | grep -qx 'xrdp-sink'; then
    echo "xrdp-sink is missing."
    exit 1
fi

if ! pactl list short sources | awk '{print $2}' | grep -qx 'xrdp-source'; then
    echo "xrdp-source is missing."
    exit 1
fi

pactl set-default-sink xrdp-sink
pactl set-default-source xrdp-source
pactl set-sink-mute xrdp-sink 0 || true
pactl set-source-mute xrdp-source 0 || true
pactl set-sink-volume xrdp-sink 100% || true
pactl set-source-volume xrdp-source 100% || true

echo "PulseAudio defaults:"
pactl info | grep -E 'Server Name|Default Sink|Default Source' || true

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

echo "Starting supervised Vesktop session with native PulseAudio XRDP audio..."

while true; do
    set +e
    /usr/bin/vesktop "${VESKTOP_FLAGS[@]}"
    EXIT_CODE=$?
    set -e

    echo "Vesktop exited with code $EXIT_CODE. Restarting in ${VESKTOP_RESTART_DELAY}s..."
    sleep "$VESKTOP_RESTART_DELAY"
done
