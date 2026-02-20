#!/usr/bin/env bash
set -euo pipefail

YOCTO_DIR="${YOCTO_DIR:-/work/yocto}"
export BBSERVER="${BBSERVER:-}"
set +u
source "${YOCTO_DIR}/sources/poky/oe-init-build-env" "${YOCTO_DIR}/build" > /dev/null
set -u

bitbake my-hu-image -c bundle

ARTIFACTS_DIR="${ARTIFACTS_DIR:-/work/out}"
mkdir -p "${ARTIFACTS_DIR}"

DEPLOY_CANDIDATES=(
  "${YOCTO_DIR}/build/tmp-glibc/deploy/images/raspberrypi4-64"
  "${YOCTO_DIR}/build/tmp/deploy/images/raspberrypi4-64"
)

DEPLOY_DIR=""
for d in "${DEPLOY_CANDIDATES[@]}"; do
  if compgen -G "${d}/*.raucb" > /dev/null; then
    DEPLOY_DIR="${d}"
    break
  fi
done

if [[ -z "${DEPLOY_DIR}" ]]; then
  echo "ERROR: could not find .raucb artifacts in known deploy directories." >&2
  exit 1
fi

echo "Using deploy directory: ${DEPLOY_DIR}"
cp -v "${DEPLOY_DIR}/"*.raucb "${ARTIFACTS_DIR}/"
