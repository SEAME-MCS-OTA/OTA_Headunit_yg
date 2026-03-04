#!/bin/sh
set -eu

TZ_NAME=""
if [ -r /etc/timezone ]; then
    TZ_NAME="$(tr -d '\r\n' < /etc/timezone)"
fi

if [ -z "${TZ_NAME}" ]; then
    TZ_NAME="Europe/Berlin"
fi

ZONEINFO="/usr/share/zoneinfo/${TZ_NAME}"
if [ ! -e "${ZONEINFO}" ]; then
    echo "myproduct-timezone: missing zoneinfo for ${TZ_NAME}"
    exit 0
fi

ln -snf "${ZONEINFO}" /etc/localtime
printf '%s\n' "${TZ_NAME}" > /etc/timezone
echo "myproduct-timezone: applied ${TZ_NAME}"

exit 0
