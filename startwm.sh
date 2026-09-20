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
CHROMIUM_RESTART_DELAY="${CHROMIUM_RESTART_DELAY:-2}"
MUSIC_BROWSER_URL="${MUSIC_BROWSER_URL:-https://www.youtube.com/}"
MIC_TO_DISCORD="${MIC_TO_DISCORD:-1}"
MUSIC_TO_DISCORD="${MUSIC_TO_DISCORD:-1}"
MONITOR_MUSIC="${MONITOR_MUSIC:-1}"

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

CHROMIUM_FLAGS=(
    --no-sandbox
    --ozone-platform=x11
    --use-gl=angle
    --use-angle=swiftshader
    --enable-unsafe-swiftshader
    --disable-renderer-backgrounding
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
    --user-data-dir="$HOME/.config/chromium-music"
)

PIPEWIRE_PID=""
PULSE_PID=""
WIREPLUMBER_PID=""
OPENBOX_PID=""
MAXIMIZER_PID=""
CHROMIUM_SUPERVISOR_PID=""

cleanup_session() {
    trap - TERM INT
    pkill -TERM -u "$(id -u)" -f '/usr/bin/vesktop|/opt/Vesktop/vesktop|vesktop|/usr/bin/chromium|chromium' 2>/dev/null || true
    [ -z "$CHROMIUM_SUPERVISOR_PID" ] || kill "$CHROMIUM_SUPERVISOR_PID" 2>/dev/null || true
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

if [ "$audio_ready" -ne 1 ]; then
    echo "PipeWire Pulse compatibility layer did not become ready."
    exit 1
fi

echo "Loading xrdp PipeWire audio sink/source..."
/usr/libexec/pipewire-module-xrdp/load_pw_modules.sh -l 2 || true

xrdp_audio_ready=0
for _ in $(seq 1 30); do
    if pactl list short sinks | awk '{print $2}' | grep -qx 'xrdp-sink' \
       && pactl list short sources | awk '{print $2}' | grep -qx 'xrdp-source'; then
        xrdp_audio_ready=1
        break
    fi
    sleep 1
done

if [ "$xrdp_audio_ready" -ne 1 ]; then
    echo "xrdp audio devices were not created."
    pactl list short sinks || true
    pactl list short sources || true
    exit 1
fi

echo "Creating internal music and Discord mix buses..."
pactl load-module module-null-sink \
    sink_name=music_bus \
    sink_properties=device.description=Music_Bus >/dev/null

pactl load-module module-null-sink \
    sink_name=discord_mix \
    sink_properties=device.description=Discord_Mix >/dev/null

if [ "$MUSIC_TO_DISCORD" = "1" ]; then
    pactl load-module module-loopback \
        source=music_bus.monitor \
        sink=discord_mix \
        latency_msec=50 >/dev/null
fi

if [ "$MIC_TO_DISCORD" = "1" ]; then
    pactl load-module module-loopback \
        source=xrdp-source \
        sink=discord_mix \
        latency_msec=50 >/dev/null
fi

if [ "$MONITOR_MUSIC" = "1" ]; then
    pactl load-module module-loopback \
        source=music_bus.monitor \
        sink=xrdp-sink \
        latency_msec=50 >/dev/null
fi

pactl set-default-sink xrdp-sink
pactl set-default-source discord_mix.monitor

echo "Audio routing:"
echo "  Chromium -> music_bus"
echo "  music_bus.monitor -> discord_mix: $MUSIC_TO_DISCORD"
echo "  xrdp-source -> discord_mix:       $MIC_TO_DISCORD"
echo "  music_bus.monitor -> xrdp-sink:   $MONITOR_MUSIC"
echo "  Vesktop mic -> discord_mix.monitor"
echo "  Vesktop speakers -> xrdp-sink"
echo
pactl list short sinks || true
pactl list short sources || true

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

supervise_chromium() {
    while true; do
        echo "Starting Chromium music browser: $MUSIC_BROWSER_URL"
        set +e
        PULSE_SINK=music_bus \
        /usr/bin/chromium "${CHROMIUM_FLAGS[@]}" "$MUSIC_BROWSER_URL"
        EXIT_CODE=$?
        set -e

        echo "Chromium exited with code $EXIT_CODE. Restarting in ${CHROMIUM_RESTART_DELAY}s..."
        sleep "$CHROMIUM_RESTART_DELAY"
    done
}

supervise_chromium &
CHROMIUM_SUPERVISOR_PID=$!

sleep 1

echo "Starting supervised Vesktop session with internal browser audio mix..."

while true; do
    set +e
    PULSE_SINK=xrdp-sink \
    PULSE_SOURCE=discord_mix.monitor \
    /usr/bin/vesktop "${VESKTOP_FLAGS[@]}"
    EXIT_CODE=$?
    set -e

    echo "Vesktop exited with code $EXIT_CODE. Restarting in ${VESKTOP_RESTART_DELAY}s..."
    sleep "$VESKTOP_RESTART_DELAY"
done
