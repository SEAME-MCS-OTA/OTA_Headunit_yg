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
PERSIST_MACHINE_ID_SERVICE_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-core/systemd/files/persist-machine-id.service"
PERSIST_MACHINE_ID_SCRIPT_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-core/systemd/files/persist-machine-id.sh"
TIMEZONE_SERVICE_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-core/systemd/files/myproduct-timezone.service"
TIMEZONE_SCRIPT_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-core/systemd/files/myproduct-timezone.sh"
UI_LOG_SERVICE_SRC="${REPO_DIR}/ui/qt-headunit/systemd/ui-log-collector.service"
UI_LOG_TIMER_SRC="${REPO_DIR}/ui/qt-headunit/systemd/ui-log-collector.timer"
UI_LOG_SCRIPT_SRC="${REPO_DIR}/ui/qt-headunit/scripts/collect-ui-logs.sh"
TIMESYNCD_DROPIN_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-core/systemd/files/10-myproduct-timesyncd.conf"
OTA_BACKEND_MAIN_SRC="${REPO_DIR}/services/ota-backend/app/main.py"
OTA_BACKEND_APP_DIR="${REPO_DIR}/services/ota-backend/app"
OTA_BACKEND_ENTRY_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-apps/ota-backend/files/ota-backend"
OTA_BACKEND_SERVICE_SRC="${REPO_DIR}/services/ota-backend/systemd/ota-backend.service"
OTA_BACKEND_PREPARE_SRC="${REPO_DIR}/services/ota-backend/systemd/ota-backend-prepare-config.sh"
OTA_BACKEND_CONFIG_SRC="${REPO_DIR}/services/ota-backend/config/default-config.json"
RAUC_SYSTEM_CONF_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-support/rauc/files/system.conf"
RAUC_BOOT_BACKEND_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-support/rauc/files/rauc-bootloader-backend.sh"
RAUC_CA_CERT_SRC="${REPO_DIR}/yocto/meta-myproduct/recipes-support/rauc/files/ca.cert.pem"

if [[ ! -f "${HEADUNIT_SERVICE_SRC}" ]]; then
  echo "Missing source file: ${HEADUNIT_SERVICE_SRC}" >&2
  exit 1
fi
if [[ ! -f "${HTTP_TIME_SYNC_SRC}" ]]; then
  echo "Missing source file: ${HTTP_TIME_SYNC_SRC}" >&2
  exit 1
fi
if [[ ! -f "${PERSIST_MACHINE_ID_SERVICE_SRC}" || ! -f "${PERSIST_MACHINE_ID_SCRIPT_SRC}" || ! -f "${TIMEZONE_SERVICE_SRC}" || ! -f "${TIMEZONE_SCRIPT_SRC}" ]]; then
  echo "Missing source file(s) for machine-id/timezone hotfix." >&2
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
if [[ ! -d "${OTA_BACKEND_APP_DIR}" || ! -f "${OTA_BACKEND_MAIN_SRC}" || ! -f "${OTA_BACKEND_ENTRY_SRC}" || ! -f "${OTA_BACKEND_SERVICE_SRC}" || ! -f "${OTA_BACKEND_PREPARE_SRC}" || ! -f "${OTA_BACKEND_CONFIG_SRC}" ]]; then
  echo "Missing ota-backend source files." >&2
  exit 1
fi
if [[ ! -f "${RAUC_SYSTEM_CONF_SRC}" || ! -f "${RAUC_BOOT_BACKEND_SRC}" || ! -f "${RAUC_CA_CERT_SRC}" ]]; then
  echo "Missing RAUC hotfix source files." >&2
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

is_rootfs_mount() {
  local d="$1"
  [[ -d "${d}/etc/systemd/system" ]] && [[ -d "${d}/usr/lib/systemd/system" || -d "${d}/lib/systemd/system" ]]
}

systemd_unit_dir_for_rootfs() {
  local d="$1"
  if [[ -d "${d}/usr/lib/systemd/system" ]]; then
    printf '%s\n' "${d}/usr/lib/systemd/system"
    return 0
  fi
  if [[ -d "${d}/lib/systemd/system" ]]; then
    printf '%s\n' "${d}/lib/systemd/system"
    return 0
  fi
  printf '\n'
  return 1
}

discover_rootfs_mounts() {
  # Auto-mount names can vary (UUID, UUID1, ...)
  for d in /media/*/*; do
    [[ -d "${d}" ]] || continue
    if is_rootfs_mount "${d}"; then
      printf '%s\n' "${d}"
    fi
  done | sort -u
}

map_rootfs_alias_if_needed() {
  local requested="$1"
  local base
  base="$(basename "${requested}")"

  if is_rootfs_mount "${requested}"; then
    printf '%s\n' "${requested}"
    return 0
  fi

  if [[ "${base}" == "rootfsA" || "${base}" == "rootfsB" ]]; then
    mapfile -t discovered < <(discover_rootfs_mounts)
    if [[ "${#discovered[@]}" -ge 2 ]]; then
      if [[ "${base}" == "rootfsA" ]]; then
        printf '%s\n' "${discovered[0]}"
      else
        printf '%s\n' "${discovered[1]}"
      fi
      return 0
    fi
  fi

  printf '%s\n' "${requested}"
  return 0
}

for REQUESTED_ROOTFS in "$@"; do
  ROOTFS="$(map_rootfs_alias_if_needed "${REQUESTED_ROOTFS}")"
  if [[ "${ROOTFS}" != "${REQUESTED_ROOTFS}" ]]; then
    echo "auto-mapped ${REQUESTED_ROOTFS} -> ${ROOTFS}"
  fi
  echo "==> Patching ${ROOTFS}"
  if ! is_rootfs_mount "${ROOTFS}"; then
    echo "Skipping ${ROOTFS}: not a valid rootfs mount." >&2
    continue
  fi

  SYSTEMD_UNIT_DIR="$(systemd_unit_dir_for_rootfs "${ROOTFS}")"
  if [[ -z "${SYSTEMD_UNIT_DIR}" ]]; then
    echo "Skipping ${ROOTFS}: systemd unit directory not found." >&2
    continue
  fi
  SYSTEMD_UNIT_LINK="${SYSTEMD_UNIT_DIR#${ROOTFS}}"

  if ! touch "${ROOTFS}/.codex-write-test" 2>/dev/null; then
    echo "Skipping ${ROOTFS}: no write permission (run with elevated privileges)." >&2
    continue
  fi
  rm -f "${ROOTFS}/.codex-write-test"

  install -m 0644 "${HEADUNIT_SERVICE_SRC}" "${SYSTEMD_UNIT_DIR}/headunit.service"
  install -m 0644 "${HTTP_TIME_SYNC_SRC}" "${SYSTEMD_UNIT_DIR}/http-time-sync.service"
  install -m 0644 "${PERSIST_MACHINE_ID_SERVICE_SRC}" "${SYSTEMD_UNIT_DIR}/persist-machine-id.service"
  install -m 0644 "${TIMEZONE_SERVICE_SRC}" "${SYSTEMD_UNIT_DIR}/myproduct-timezone.service"
  install -m 0644 "${UI_LOG_SERVICE_SRC}" "${SYSTEMD_UNIT_DIR}/ui-log-collector.service"
  install -m 0644 "${UI_LOG_TIMER_SRC}" "${SYSTEMD_UNIT_DIR}/ui-log-collector.timer"
  install -d "${ROOTFS}/usr/lib/headunit-ui"
  install -m 0755 "${UI_LOG_SCRIPT_SRC}" "${ROOTFS}/usr/lib/headunit-ui/collect-ui-logs.sh"
  install -d "${ROOTFS}/usr/sbin"
  install -m 0755 "${PERSIST_MACHINE_ID_SCRIPT_SRC}" "${ROOTFS}/usr/sbin/persist-machine-id.sh"
  install -m 0755 "${TIMEZONE_SCRIPT_SRC}" "${ROOTFS}/usr/sbin/myproduct-timezone.sh"
  install -m 0755 "${OTA_BACKEND_PREPARE_SRC}" "${ROOTFS}/usr/sbin/ota-backend-prepare-config.sh"
  install -d "${ROOTFS}/etc/systemd/timesyncd.conf.d"
  install -m 0644 "${TIMESYNCD_DROPIN_SRC}" "${ROOTFS}/etc/systemd/timesyncd.conf.d/10-myproduct.conf"
  install -d "${ROOTFS}/usr/lib/ota-backend"
  rm -rf "${ROOTFS}/usr/lib/ota-backend/app"
  cp -a "${OTA_BACKEND_APP_DIR}" "${ROOTFS}/usr/lib/ota-backend/"
  install -d "${ROOTFS}/usr/bin"
  install -m 0755 "${OTA_BACKEND_ENTRY_SRC}" "${ROOTFS}/usr/bin/ota-backend"
  install -m 0644 "${OTA_BACKEND_SERVICE_SRC}" "${SYSTEMD_UNIT_DIR}/ota-backend.service"
  install -d "${ROOTFS}/etc/ota-backend"
  install -m 0644 "${OTA_BACKEND_CONFIG_SRC}" "${ROOTFS}/etc/ota-backend/config.json"
  install -d "${ROOTFS}/etc/rauc"
  install -m 0644 "${RAUC_SYSTEM_CONF_SRC}" "${ROOTFS}/etc/rauc/system.conf"
  install -m 0644 "${RAUC_CA_CERT_SRC}" "${ROOTFS}/etc/rauc/ca.cert.pem"
  install -m 0755 "${RAUC_BOOT_BACKEND_SRC}" "${ROOTFS}/usr/sbin/rauc-bootloader-backend.sh"
  echo "  ota-backend main hash: $(sha256sum "${ROOTFS}/usr/lib/ota-backend/app/main.py" | awk '{print $1}')"
  echo "  ota-backend logic hash:$(sha256sum "${ROOTFS}/usr/lib/ota-backend/app/ota_logic.py" | awk '{print $1}')"
  echo "  ota-backend cfg hash:  $(sha256sum "${ROOTFS}/etc/ota-backend/config.json" | awk '{print $1}')"
  echo "  rauc system.conf hash: $(sha256sum "${ROOTFS}/etc/rauc/system.conf" | awk '{print $1}')"
  echo "  rauc backend hash:     $(sha256sum "${ROOTFS}/usr/sbin/rauc-bootloader-backend.sh" | awk '{print $1}')"
  echo "  ui log script hash:    $(sha256sum "${ROOTFS}/usr/lib/headunit-ui/collect-ui-logs.sh" | awk '{print $1}')"

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
  if [[ -f "${ROOTFS}/etc/systemd/system/persist-machine-id.service" ]]; then
    mv "${ROOTFS}/etc/systemd/system/persist-machine-id.service" \
       "${ROOTFS}/etc/systemd/system/persist-machine-id.service.bak.${timestamp}"
    echo "  moved stale override: /etc/systemd/system/persist-machine-id.service"
  fi
  if [[ -f "${ROOTFS}/etc/systemd/system/myproduct-timezone.service" ]]; then
    mv "${ROOTFS}/etc/systemd/system/myproduct-timezone.service" \
       "${ROOTFS}/etc/systemd/system/myproduct-timezone.service.bak.${timestamp}"
    echo "  moved stale override: /etc/systemd/system/myproduct-timezone.service"
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
  if [[ -f "${ROOTFS}/etc/systemd/system/ota-backend.service" ]]; then
    mv "${ROOTFS}/etc/systemd/system/ota-backend.service" \
       "${ROOTFS}/etc/systemd/system/ota-backend.service.bak.${timestamp}"
    echo "  moved stale override: /etc/systemd/system/ota-backend.service"
  fi

  install -d "${ROOTFS}/etc/systemd/system/multi-user.target.wants"
  install -d "${ROOTFS}/etc/systemd/system/timers.target.wants"
  ln -sf "${SYSTEMD_UNIT_LINK}/headunit.service" \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/headunit.service"
  ln -sf "${SYSTEMD_UNIT_LINK}/http-time-sync.service" \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/http-time-sync.service"
  ln -sf "${SYSTEMD_UNIT_LINK}/persist-machine-id.service" \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/persist-machine-id.service"
  ln -sf "${SYSTEMD_UNIT_LINK}/myproduct-timezone.service" \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/myproduct-timezone.service"
  ln -sf "${SYSTEMD_UNIT_LINK}/ui-log-collector.service" \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/ui-log-collector.service"
  ln -sf "${SYSTEMD_UNIT_LINK}/ota-backend.service" \
    "${ROOTFS}/etc/systemd/system/multi-user.target.wants/ota-backend.service"
  ln -sf "${SYSTEMD_UNIT_LINK}/ui-log-collector.timer" \
    "${ROOTFS}/etc/systemd/system/timers.target.wants/ui-log-collector.timer"

  if [[ -n "${NEW_UI_BIN}" ]]; then
    install -m 0755 "${NEW_UI_BIN}" "${ROOTFS}/usr/bin/headunit-ui"
    echo "  updated binary: /usr/bin/headunit-ui"
    echo "  target hash: $(sha256sum "${ROOTFS}/usr/bin/headunit-ui" | awk '{print $1}')"
  fi
done

sync
echo "Done."
