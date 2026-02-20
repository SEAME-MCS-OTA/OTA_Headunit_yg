#!/usr/bin/env bash
set -euo pipefail

YOCTO_DIR="${YOCTO_DIR:-/work/yocto}"
BRANCH="${YOCTO_BRANCH:-scarthgap}"

mkdir -p "${YOCTO_DIR}/sources"

fetch_repo() {
  local name="$1"
  local url="$2"
  local env_ref="$3"
  local dest="${YOCTO_DIR}/sources/${name}"
  if [ ! -d "${dest}/.git" ]; then
    git clone "${url}" "${dest}"
  fi
  git -C "${dest}" fetch --all --tags
  if [ -f "${YOCTO_DIR}/sources/yocto-lock.env" ]; then
    # shellcheck disable=SC1090
    source "${YOCTO_DIR}/sources/yocto-lock.env"
  fi
  local ref_var="${env_ref}_REF"
  local ref="${!ref_var:-${BRANCH}}"
  if ! git -C "${dest}" checkout "${ref}"; then
    echo "WARN: ${name} has no '${ref}' branch, trying 'master' or 'main'." >&2
    if git -C "${dest}" checkout master || git -C "${dest}" checkout main; then
      return
    fi
    if [ "${name}" = "meta-qt6" ]; then
      if git -C "${dest}" show-ref --verify --quiet refs/heads/dev || \
         git -C "${dest}" show-ref --verify --quiet refs/remotes/origin/dev; then
        echo "WARN: meta-qt6 fallback to branch 'dev'." >&2
        git -C "${dest}" checkout dev || git -C "${dest}" checkout origin/dev
        return
      fi
      local tag
      tag="$(git -C "${dest}" tag -l "6.*" | sort -V | tail -1)"
      if [ -z "${tag}" ]; then
        tag="$(git -C "${dest}" tag -l "v6.*" | sort -V | tail -1)"
      fi
      if [ -n "${tag}" ]; then
        echo "WARN: meta-qt6 fallback to tag '${tag}'." >&2
        git -C "${dest}" checkout "${tag}"
        return
      fi
    fi
    # meta-qt5 is deprecated in newer Yocto; avoid using it by default.
    echo "ERROR: Could not find a usable ref for ${name}." >&2
    exit 1
  fi
}

fetch_repo poky https://git.yoctoproject.org/poky POKY
fetch_repo meta-openembedded https://git.openembedded.org/meta-openembedded META_OPENEMBEDDED
fetch_repo meta-raspberrypi https://github.com/agherzan/meta-raspberrypi.git META_RASPBERRYPI
fetch_repo meta-rauc https://github.com/rauc/meta-rauc.git META_RAUC
fetch_repo meta-qt6 https://code.qt.io/yocto/meta-qt6.git META_QT6

mkdir -p "${YOCTO_DIR}/build/conf"
cp -n /work/yocto/conf/bblayers.conf.sample "${YOCTO_DIR}/build/conf/bblayers.conf" || true
cp -n /work/yocto/conf/local.conf.sample "${YOCTO_DIR}/build/conf/local.conf" || true

if ! grep -q "meta-openembedded" "${YOCTO_DIR}/build/conf/bblayers.conf"; then
  echo "WARN: bblayers.conf looks minimal; replacing with sample." >&2
  cp /work/yocto/conf/bblayers.conf.sample "${YOCTO_DIR}/build/conf/bblayers.conf"
fi

if grep -q "meta-qt5" "${YOCTO_DIR}/build/conf/bblayers.conf"; then
  sed -i "s/meta-qt5/meta-qt6/" "${YOCTO_DIR}/build/conf/bblayers.conf"
fi

if ! grep -q "meta-myproduct" "${YOCTO_DIR}/build/conf/bblayers.conf"; then
  echo "WARN: meta-myproduct missing in bblayers.conf, appending." >&2
  cat >> "${YOCTO_DIR}/build/conf/bblayers.conf" <<'EOF'

# Added by tools/yocto-init.sh
BBLAYERS += " ${TOPDIR}/../meta-myproduct "
EOF
fi

# Keep custom weston service active for auto-start of weston/headunit.
if grep -q "weston-service.bb" "${YOCTO_DIR}/build/conf/local.conf"; then
  sed -i '/weston-service\.bb/d' "${YOCTO_DIR}/build/conf/local.conf"
fi

echo "Yocto init complete in ${YOCTO_DIR}."
