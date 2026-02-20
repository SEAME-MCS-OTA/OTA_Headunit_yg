#!/usr/bin/env bash
set -euo pipefail

YOCTO_DIR="${YOCTO_DIR:-/work/yocto}"
export BBSERVER="${BBSERVER:-}"
set +u
source "${YOCTO_DIR}/sources/poky/oe-init-build-env" "${YOCTO_DIR}/build" > /dev/null
set -u

bitbake my-hu-image

ARTIFACTS_DIR="${ARTIFACTS_DIR:-/work/out}"
mkdir -p "${ARTIFACTS_DIR}"

DEPLOY_CANDIDATES=(
  "${YOCTO_DIR}/build/tmp-glibc/deploy/images/raspberrypi4-64"
  "${YOCTO_DIR}/build/tmp/deploy/images/raspberrypi4-64"
)

DEPLOY_DIR=""
for d in "${DEPLOY_CANDIDATES[@]}"; do
  if compgen -G "${d}/my-hu-image*" > /dev/null; then
    DEPLOY_DIR="${d}"
    break
  fi
done

if [[ -z "${DEPLOY_DIR}" ]]; then
  echo "ERROR: could not find my-hu-image artifacts in known deploy directories." >&2
  exit 1
fi

echo "Using deploy directory: ${DEPLOY_DIR}"
cp -v "${DEPLOY_DIR}/"my-hu-image* "${ARTIFACTS_DIR}/"

# Refresh convenience symlinks to the newest timestamped artifacts in out/.
set_latest_link() {
  local pattern="$1"
  local link_name="$2"
  local latest
  latest="$(ls -1 "${ARTIFACTS_DIR}"/${pattern} 2>/dev/null | sort | tail -n1 || true)"
  if [[ -n "${latest}" ]]; then
    ln -sfn "$(basename "${latest}")" "${ARTIFACTS_DIR}/${link_name}"
  fi
}

set_latest_link "my-hu-image-raspberrypi4-64.rootfs-*.wic.gz" "my-hu-image-raspberrypi4-64.rootfs.wic.gz"
set_latest_link "my-hu-image-raspberrypi4-64.rootfs-*.manifest" "my-hu-image-raspberrypi4-64.rootfs.manifest"
set_latest_link "my-hu-image-raspberrypi4-64.rootfs-*.spdx.tar.zst" "my-hu-image-raspberrypi4-64.rootfs.spdx.tar.zst"
set_latest_link "my-hu-image-raspberrypi4-64.rootfs-*.testdata.json" "my-hu-image-raspberrypi4-64.rootfs.testdata.json"
