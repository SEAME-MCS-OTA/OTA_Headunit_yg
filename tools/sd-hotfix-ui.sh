#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "Usage: $0 <rootfs-mount> [<rootfs-mount> ...]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

HEADUNIT_SERVICE_SRC="${REPO_DIR}/ui/qt-headunit/systemd/headunit.service"
HTTP_TIME_SYNC_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-core/systemd/files/http-time-sync.service"
UI_LOG_SERVICE_SRC="${REPO_DIR}/ui/qt-headunit/systemd/ui-log-collector.service"
UI_LOG_TIMER_SRC="${REPO_DIR}/ui/qt-headunit/systemd/ui-log-collector.timer"
UI_LOG_SCRIPT_SRC="${REPO_DIR}/ui/qt-headunit/scripts/collect-ui-logs.sh"
TIMESYNCD_DROPIN_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-core/systemd/files/10-myproduct-timesyncd.conf"

if [[ ! -f "${HEADUNIT_SERVICE_SRC}" ]]; then
  echo "Missing source file: ${HEADUNIT_SERVICE_SRC}" >&2
  exit 1
fi
if [[ ! -f "${HTTP_TIME_SYNC_SRC}" ]]; then
  echo "Missing source file: ${HTTP_TIME_SYNC_SRC}" >&2
  exit 1
fi
if [[ ! -f "${UI_LOG_SERVICE_SRC}" || ! -f "${UI_LOG_TIMER_SRC}" || ! -f "${UI_LOG_SCRIPT_SRC}" ]]; then
  echo "Missing ui log collector source files." >&2
  exit 1
fi
if [[ ! -f "${TIMESYNCD_DROPIN_SRC}" ]]; then
  echo "Missing source file: ${TIMESYNCD_DROPIN_SRC}" >&2
  exit 1
fi

CANDIDATE_BINARIES=(
  "${REPO_DIR}/_build/tmp-glibc/work/cortexa72-oe-linux/headunit-ui/1.0/packages-split/headunit-ui/usr/bin/headunit-ui"
  "${REPO_DIR}/_build/tmp-glibc/work/raspberrypi4_64-oe-linux/my-hu-image/1.0/rootfs/usr/bin/headunit-ui"
  "${REPO_DIR}/_build/tmp/work/cortexa72-oe-linux/headunit-ui/1.0/packages-split/headunit-ui/usr/bin/headunit-ui"
  "${REPO_DIR}/_build/tmp/work/raspberrypi4_64-oe-linux/my-hu-image/1.0/rootfs/usr/bin/headunit-ui"
)

NEW_UI_BIN=""
for c in "${CANDIDATE_BINARIES[@]}"; do
  if [[ -f "${c}" ]]; then
    NEW_UI_BIN="${c}"
    break
  fi
done

if [[ -z "${NEW_UI_BIN}" ]]; then
  echo "WARNING: built headunit-ui binary not found in _build. Service files will still be updated." >&2
fi

timestamp="$(date +%Y%m%d-%H%M%S)"

for ROOTFS in "$@"; do
  echo "==> Patching ${ROOTFS}"
  if [[ ! -d "${ROOTFS}/usr/lib/systemd/system" || ! -d "${ROOTFS}/etc/systemd/system" ]]; then
    echo "Skipping ${ROOTFS}: not a valid rootfs mount." >&2
    continue
  fi

  if ! touch "${ROOTFS}/.codex-write-test" 2>/dev/null; then
    echo "Skipping ${ROOTFS}: no write permission (run with elevated privileges)." >&2
    continue
  fi
  rm -f "${ROOTFS}/.codex-write-test"

  install -m 0644 "${HEADUNIT_SERVICE_SRC}" "${ROOTFS}/usr/lib/systemd/system/headunit.service"
  install -m 0644 "${HTTP_TIME_SYNC_SRC}" "${ROOTFS}/usr/lib/systemd/system/http-time-sync.service"
  install -m 0644 "${UI_LOG_SERVICE_SRC}" "${ROOTFS}/usr/lib/systemd/system/ui-log-collector.service"
  install -m 0644 "${UI_LOG_TIMER_SRC}" "${ROOTFS}/usr/lib/systemd/system/ui-log-collector.timer"
  install -d "${ROOTFS}/usr/lib/headunit-ui"
  install -m 0755 "${UI_LOG_SCRIPT_SRC}" "${ROOTFS}/usr/lib/headunit-ui/collect-ui-logs.sh"
  install -d "${ROOTFS}/etc/systemd/timesyncd.conf.d"
  install -m 0644 "${TIMESYNCD_DROPIN_SRC}" "${ROOTFS}/etc/systemd/timesyncd.conf.d/10-myproduct.conf"

  if [[ -f "${ROOTFS}/etc/systemd/system/headunit.service" ]]; then
    mv "${ROOTFS}/etc/systemd/system/headunit.service" \
       "${ROOTFS}/etc/systemd/system/headunit.service.bak.${timestamp}"
    echo "  moved stale override: /etc/systemd/system/headunit.service"
  fi
  if [[ -f "${ROOTFS}/etc/systemd/system/http-time-sync.service" ]]; then
    mv "${ROOTFS}/etc/systemd/system/http-time-sync.service" \
       "${ROOTFS}/etc/systemd/system/http-time-sync.service.bak.${timestamp}"
    echo "  moved stale override: /etc/systemd/system/http-time-sync.service"
  fi
  if [[ -f "${ROOTFS}/etc/systemd/system/ui-log-collector.service" ]]; then
    mv "${ROOTFS}/etc/systemd/system/ui-log-collector.service" \
       "${ROOTFS}/etc/systemd/system/ui-log-collector.service.bak.${timestamp}"
    echo "  moved stale override: /etc/systemd/system/ui-log-collector.service"
  fi
  if [[ -f "${ROOTFS}/etc/systemd/system/ui-log-collector.timer" ]]; then
    mv "${ROOTFS}/etc/systemd/system/ui-log-collector.timer" \
       "${ROOTFS}/etc/systemd/system/ui-log-collector.timer.bak.${timestamp}"
    echo "  moved stale override: /etc/systemd/system/ui-log-collector.timer"
  fi

  install -d "${ROOTFS}/etc/systemd/system/multi-user.target.wants"
  install -d "${ROOTFS}/etc/systemd/system/timers.target.wants"
  ln -sf /usr/lib/systemd/system/headunit.service \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/headunit.service"
  ln -sf /usr/lib/systemd/system/http-time-sync.service \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/http-time-sync.service"
  ln -sf /usr/lib/systemd/system/ui-log-collector.service \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/ui-log-collector.service"
  ln -sf /usr/lib/systemd/system/ui-log-collector.timer \
    "${ROOTFS}/etc/systemd/system/timers.target.wants/ui-log-collector.timer"

  if [[ -n "${NEW_UI_BIN}" ]]; then
    install -m 0755 "${NEW_UI_BIN}" "${ROOTFS}/usr/bin/headunit-ui"
    echo "  updated binary: /usr/bin/headunit-ui"
    echo "  target hash: $(sha256sum "${ROOTFS}/usr/bin/headunit-ui" | awk '{print $1}')"
  fi
done

sync
echo "Done."
