#!/usr/bin/env bash
set -euo pipefail

YOCTO_DIR="${YOCTO_DIR:-/work/yocto}"
export BBSERVER="${BBSERVER:-}"
set +u
source "${YOCTO_DIR}/sources/poky/oe-init-build-env" "${YOCTO_DIR}/build" > /dev/null
set -u

# Build the dedicated RAUC bundle recipe when available.
# Keep legacy fallback only for branches that do not define my-hu-bundle.
if bitbake -e my-hu-bundle >/dev/null 2>&1; then
  bitbake my-hu-bundle
else
  echo "WARN: my-hu-bundle recipe not found, falling back to my-hu-image -c bundle" >&2
  bitbake my-hu-image -c bundle
fi

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
