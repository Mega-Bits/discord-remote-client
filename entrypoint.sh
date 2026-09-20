#!/bin/bash
set -euo pipefail

RDP_PASSWORD="${RDP_PASSWORD:-changeme}"
RDP_MAX_BPP="${RDP_MAX_BPP:-16}"

SESMAN_PID=""
XRDP_PID=""

cleanup() {
    trap - TERM INT
    echo "Stopping xrdp..."
    [ -z "$XRDP_PID" ] || kill "$XRDP_PID" 2>/dev/null || true
    [ -z "$SESMAN_PID" ] || kill "$SESMAN_PID" 2>/dev/null || true
    pkill -TERM -u 1000 -f '/usr/bin/vesktop|/opt/Vesktop/vesktop|vesktop' 2>/dev/null || true
}
trap cleanup TERM INT EXIT

echo "Preparing Vesktop RDP container..."

case "$RDP_MAX_BPP" in
    8|15|16|24|32) ;;
    *)
        echo "Invalid RDP_MAX_BPP=$RDP_MAX_BPP; expected 8, 15, 16, 24 or 32."
        exit 1
        ;;
esac

echo "Tuning xrdp for CPU-only rendering (max_bpp=$RDP_MAX_BPP)..."
sed -ri "s/^max_bpp=.*/max_bpp=$RDP_MAX_BPP/" /etc/xrdp/xrdp.ini
sed -ri 's/^bitmap_cache=.*/bitmap_cache=true/' /etc/xrdp/xrdp.ini
sed -ri 's/^bitmap_compression=.*/bitmap_compression=true/' /etc/xrdp/xrdp.ini
sed -ri 's/^bulk_compression=.*/bulk_compression=true/' /etc/xrdp/xrdp.ini
sed -ri 's/^use_fastpath=.*/use_fastpath=both/' /etc/xrdp/xrdp.ini
sed -ri 's/^allow_multimon=.*/allow_multimon=false/' /etc/xrdp/xrdp.ini

mkdir -p /home/discord/.config
chown -R discord:discord /home/discord

echo "Configuring RDP login for user discord..."
printf 'discord:%s\n' "$RDP_PASSWORD" | chpasswd

echo "Starting system DBus..."
mkdir -p /run/dbus
rm -f /run/dbus/system_bus_socket /run/dbus/pid
dbus-daemon --system --fork

echo "Preparing xrdp runtime..."
mkdir -p /run/xrdp /run/xrdp/sockdir /var/run/xrdp
chmod 755 /run/xrdp
chmod 1777 /run/xrdp/sockdir
rm -f /run/xrdp/xrdp.pid /run/xrdp/xrdp-sesman.pid /var/run/xrdp.pid /var/run/xrdp-sesman.pid

echo "Starting xrdp session manager..."
/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!

sleep 1
if ! kill -0 "$SESMAN_PID" 2>/dev/null; then
    echo "xrdp-sesman failed to start."
    exit 1
fi

echo "Starting xrdp on port 3389..."
/usr/sbin/xrdp --nodaemon --port 3389 &
XRDP_PID=$!

sleep 1
if ! kill -0 "$XRDP_PID" 2>/dev/null; then
    echo "xrdp failed to start."
    exit 1
fi

echo "RDP ready: user=discord port=3389"
echo "Audio output and microphone redirection are provided by PipeWire xrdp modules."

while true; do
    if ! kill -0 "$SESMAN_PID" 2>/dev/null; then
        echo "xrdp-sesman exited unexpectedly."
        exit 1
    fi

    if ! kill -0 "$XRDP_PID" 2>/dev/null; then
        echo "xrdp exited unexpectedly."
        exit 1
    fi

    sleep 5
done
