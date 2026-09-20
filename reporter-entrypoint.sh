#!/bin/bash
set -euo pipefail

export HOME=/home/discord
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-discord
export XDG_SESSION_TYPE=x11
export VENCORD_USER_DATA_DIR=/home/discord/.config/Vencord
export VENCORD_DEV_INSTALL=1
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
unset WAYLAND_DISPLAY

DISCORD_FLAGS=(
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
    mkdir -p /home/discord/.config /home/discord/.vnc "$XDG_RUNTIME_DIR" /tmp/.X11-unix /run/dbus
    chown -R discord:discord /home/discord "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    chmod 1777 /tmp/.X11-unix
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 /run/dbus/system_bus_socket /run/dbus/pid

    dbus-daemon --system --fork
    exec gosu discord "$0"
fi

cleanup() {
    pkill -TERM -u "$(id -u)" -f '/usr/bin/discord|/home/discord/.config/discord/app-' 2>/dev/null || true
    [ -z "${VNC_PID:-}" ] || kill "$VNC_PID" 2>/dev/null || true
}
trap cleanup EXIT TERM INT

printf 'reporter\n' | tigervncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

Xtigervnc :1 \
    -geometry 1920x1080 \
    -depth 24 \
    -rfbport 5900 \
    -SecurityTypes VncAuth \
    -PasswordFile "$HOME/.vnc/passwd" \
    -localhost yes \
    -nolisten tcp &
VNC_PID=$!

for _ in $(seq 1 30); do
    DISPLAY=:1 xdpyinfo >/dev/null 2>&1 && break
    sleep 1
done

openbox --sm-disable >/tmp/openbox.log 2>&1 &

echo "== Vencord desktop reporter build =="
cat /usr/local/share/vencord-reporter-dist/REPORTER_BUILD_REF || true

echo "== Bootstrapping vanilla Discord =="
: > /tmp/discord-bootstrap.log
dbus-run-session -- /usr/bin/discord "${DISCORD_FLAGS[@]}" \
    > >(tee -a /tmp/discord-bootstrap.log) \
    2> >(tee -a /tmp/discord-bootstrap.log >&2) &
BOOT_PID=$!

ready=0
for _ in $(seq 1 600); do
    if grep -q 'splashScreen.pageReady' /tmp/discord-bootstrap.log 2>/dev/null; then
        ready=1
        break
    fi

    if ! kill -0 "$BOOT_PID" 2>/dev/null; then
        break
    fi

    sleep 1
done

if [ "$ready" -ne 1 ]; then
    echo "Vanilla Discord did not reach pageReady."
    exit 20
fi

echo "== Vanilla Discord reached pageReady =="
pkill -TERM -u "$(id -u)" -f '/usr/bin/discord|/home/discord/.config/discord/app-' 2>/dev/null || true
sleep 4

echo "== Installing Vencord desktop reporter =="
rm -rf "$VENCORD_USER_DATA_DIR/dist"
mkdir -p "$VENCORD_USER_DATA_DIR/dist"
cp -a /usr/local/share/vencord-reporter-dist/. "$VENCORD_USER_DATA_DIR/dist/"

/usr/local/bin/vencord-installer --install --location "$HOME/.config/discord"

echo "== Running patched Discord with desktop reporter =="
: > /tmp/vencord-desktop-reporter.log
dbus-run-session -- /usr/bin/discord "${DISCORD_FLAGS[@]}" \
    > >(tee -a /tmp/vencord-desktop-reporter.log) \
    2> >(tee -a /tmp/vencord-desktop-reporter.log >&2) &
REPORTER_PID=$!

finished=0
for _ in $(seq 1 240); do
    if grep -qE 'Reporter.*Finished test|Reporter.*A fatal error occurred' /tmp/vencord-desktop-reporter.log 2>/dev/null; then
        finished=1
        break
    fi

    if ! kill -0 "$REPORTER_PID" 2>/dev/null; then
        break
    fi

    sleep 1
done

echo
echo "== Desktop reporter summary =="
grep -E 'Reporter|WebpackPatcher|PluginManager|pageReady|full-interactive|Uncaught|fatal|error' \
    /tmp/vencord-desktop-reporter.log || true

if [ "$finished" -ne 1 ]; then
    echo "Desktop reporter did not finish within 240 seconds."
    exit 21
fi

echo "Desktop reporter finished."
