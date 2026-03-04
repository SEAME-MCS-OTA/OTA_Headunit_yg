#!/bin/sh
set -eu

PERSIST_DIR="/data/etc"
PERSIST_ID="${PERSIST_DIR}/machine-id"
RUNTIME_ID="/etc/machine-id"

normalize_id() {
    tr -d '\r\n' < "$1" | tr '[:upper:]' '[:lower:]'
}

is_valid_machine_id() {
    file="$1"
    [ -r "$file" ] || return 1
    id="$(normalize_id "$file" 2>/dev/null || true)"
    [ "${#id}" -eq 32 ] || return 1
    printf '%s' "$id" | grep -Eq '^[0-9a-f]{32}$'
}

write_machine_id() {
    id="$1"
    dst="$2"
    printf '%s\n' "$id" > "$dst"
    chmod 0644 "$dst"
}

mkdir -p "${PERSIST_DIR}"

if is_valid_machine_id "${PERSIST_ID}"; then
    persist_id="$(normalize_id "${PERSIST_ID}")"
    if ! is_valid_machine_id "${RUNTIME_ID}" || [ "$(normalize_id "${RUNTIME_ID}" 2>/dev/null || true)" != "${persist_id}" ]; then
        write_machine_id "${persist_id}" "${RUNTIME_ID}"
        echo "persist-machine-id: applied persistent machine-id"
    fi
elif is_valid_machine_id "${RUNTIME_ID}"; then
    runtime_id="$(normalize_id "${RUNTIME_ID}")"
    write_machine_id "${runtime_id}" "${PERSIST_ID}"
    echo "persist-machine-id: initialized /data machine-id"
else
    if command -v systemd-machine-id-setup >/dev/null 2>&1; then
        systemd-machine-id-setup >/dev/null 2>&1 || true
    fi
    if is_valid_machine_id "${RUNTIME_ID}"; then
        runtime_id="$(normalize_id "${RUNTIME_ID}")"
        write_machine_id "${runtime_id}" "${PERSIST_ID}"
        echo "persist-machine-id: generated machine-id"
    fi
fi

exit 0
