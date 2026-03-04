#!/bin/sh
set -eu

PRIMARY_LOG_DIR="/data/log/ui"
FALLBACK_LOG_DIR="/boot/log/ui"
ROOTFS_FALLBACK_LOG_DIR="/var/lib/headunit-ui/log/ui"
TMP_LOG_DIR="/tmp/log/ui"
TS="$(date +%Y%m%d-%H%M%S)"
BOOT_ID="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | cut -d- -f1 || echo nobootid)"
umask 022

choose_log_dir() {
    for d in "${PRIMARY_LOG_DIR}" "${FALLBACK_LOG_DIR}" "${ROOTFS_FALLBACK_LOG_DIR}" "${TMP_LOG_DIR}"; do
        if mkdir -p "${d}" 2>/dev/null; then
            if touch "${d}/.write-test" 2>/dev/null; then
                rm -f "${d}/.write-test"
                echo "${d}"
                return 0
            fi
        fi
    done
    return 1
}

LOG_DIR="$(choose_log_dir || true)"
if [ -z "${LOG_DIR}" ]; then
    exit 0
fi

SNAPSHOT="${LOG_DIR}/boot-${TS}-${BOOT_ID}.log"
echo "${TS} ${BOOT_ID} ${LOG_DIR}" > "${LOG_DIR}/collector-last-run.txt"

{
    echo "=== UI Log Snapshot ${TS} ==="
    echo "boot_id: ${BOOT_ID}"
    echo "log_dir: ${LOG_DIR}"
    echo
    echo "=== date ==="
    date || true
    echo
    echo "=== kernel / cmdline ==="
    uname -a || true
    cat /proc/cmdline || true
    echo
    echo "=== command availability ==="
    command -v ip || true
    command -v hostname || true
    command -v curl || true
    command -v wget || true
    command -v iw || true
    command -v ifconfig || true
    echo
    echo "=== network summary ==="
    ip addr || true
    echo
    ip route || true
    echo
    if command -v iw >/dev/null 2>&1; then
        iw dev wlan0 link || true
        echo
    fi
    if command -v curl >/dev/null 2>&1; then
        echo "=== curl connectivity ==="
        curl -I --max-time 5 http://google.com || true
        echo
        curl -I --max-time 8 https://tile.openstreetmap.org/0/0/0.png || true
        echo
        curl -I --max-time 8 https://m.youtube.com || true
        echo
    fi
    echo "=== ota status endpoint ==="
    if command -v curl >/dev/null 2>&1; then
        curl -sS --max-time 8 -w "\nHTTP_CODE:%{http_code}\n" http://127.0.0.1:8080/ota/status 2>&1 || true
    elif command -v wget >/dev/null 2>&1; then
        wget -O- http://127.0.0.1:8080/ota/status 2>&1 || true
    else
        echo "curl/wget unavailable"
    fi
    echo
    echo "=== ip diagnostics ==="
    /usr/sbin/ip -4 addr show scope global 2>/dev/null || true
    echo
    /usr/sbin/ip -4 addr show 2>/dev/null || true
    echo
    /usr/sbin/ip addr show 2>/dev/null || true
    echo
    /sbin/ip -4 addr show scope global 2>/dev/null || true
    echo
    ip -4 addr show scope global 2>/dev/null || true
    echo
    ip -4 addr show 2>/dev/null || true
    echo
    ip addr show 2>/dev/null || true
    echo
    hostname -I 2>/dev/null || true
    echo
    if command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null || true
        echo
    fi
    echo "--- /proc/net/route ---"
    cat /proc/net/route 2>/dev/null || true
    echo
    echo "--- /proc/net/fib_trie (head) ---"
    sed -n '1,220p' /proc/net/fib_trie 2>/dev/null || true
    echo
    echo "--- resolv.conf ---"
    cat /etc/resolv.conf 2>/dev/null || true
    echo
    echo "=== systemctl status ==="
    systemctl --no-pager --full status \
        weston.service headunit.service ota-backend.service http-time-sync.service systemd-timesyncd.service \
        persist-machine-id.service myproduct-timezone.service \
        wpa_supplicant@wlan0.service dhcpcd.service || true
    echo
    echo "=== weston runtime dir ==="
    ls -la /run/weston || true
    echo
    echo "=== DRM devices ==="
    ls -la /dev/dri || true
    echo
    echo "=== weston journal (boot) ==="
    journalctl -u weston.service -b --no-pager -n 300 || true
    echo
    echo "=== headunit journal (boot) ==="
    journalctl -u headunit.service -b --no-pager -n 300 || true
    echo
    echo "=== ota-backend journal (boot) ==="
    journalctl -u ota-backend.service -b --no-pager -n 300 || true
    echo
    echo "=== time sync journal (boot) ==="
    journalctl -u http-time-sync.service -u systemd-timesyncd.service -u myproduct-timezone.service -b --no-pager -n 200 || true
    echo
    echo "=== machine-id journal (boot) ==="
    journalctl -u persist-machine-id.service -b --no-pager -n 120 || true
    echo
    echo "=== wlan journal (boot) ==="
    journalctl -u wpa_supplicant@wlan0.service -u dhcpcd.service -b --no-pager -n 200 || true
} > "${SNAPSHOT}"

journalctl -u weston.service -b --no-pager -n 500 > "${LOG_DIR}/weston-journal.log" || true
journalctl -u headunit.service -b --no-pager -n 500 > "${LOG_DIR}/headunit-journal.log" || true
journalctl -u ota-backend.service -b --no-pager -n 500 > "${LOG_DIR}/ota-backend-journal.log" || true
journalctl -u http-time-sync.service -u systemd-timesyncd.service -u myproduct-timezone.service -b --no-pager -n 500 > "${LOG_DIR}/time-journal.log" || true
journalctl -u persist-machine-id.service -b --no-pager -n 300 > "${LOG_DIR}/machineid-journal.log" || true
journalctl -u wpa_supplicant@wlan0.service -u dhcpcd.service -b --no-pager -n 500 > "${LOG_DIR}/network-journal.log" || true

if command -v curl >/dev/null 2>&1; then
    curl -sS --max-time 8 -w "\nHTTP_CODE:%{http_code}\n" http://127.0.0.1:8080/ota/status > "${LOG_DIR}/ota-status.json" 2>&1 || true
elif command -v wget >/dev/null 2>&1; then
    wget -O- http://127.0.0.1:8080/ota/status > "${LOG_DIR}/ota-status.json" 2>&1 || true
fi

if [ -f /run/weston/weston.log ]; then
    cp /run/weston/weston.log "${LOG_DIR}/weston-runtime.log" || true
fi
