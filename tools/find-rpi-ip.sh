#!/usr/bin/env bash
set -euo pipefail

# Default target IP requested by current environment.
DEFAULT_IP="${RPI_DEFAULT_IP:-192.168.86.250}"
HOSTNAME_CANDIDATE="${RPI_HOSTNAME:-raspberrypi4-64.local}"
SUBNET_PREFIX="${RPI_SUBNET_PREFIX:-192.168.86}"
OTA_SERVER_CONTAINER="${OTA_GH_SERVER_CONTAINER:-ota_headunit-ota_gh_server-1}"

PRINT_SOURCE=0
if [[ "${1:-}" == "--with-source" ]]; then
  PRINT_SOURCE=1
fi

emit() {
  local ip="$1"
  local src="$2"
  if [[ "$PRINT_SOURCE" -eq 1 ]]; then
    echo "${ip} ${src}"
  else
    echo "${ip}"
  fi
}

is_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local o1 o2 o3 o4
  IFS='.' read -r o1 o2 o3 o4 <<<"$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    (( o >= 0 && o <= 255 )) || return 1
  done
}

port22_open() {
  local ip="$1"
  timeout 1 bash -c "</dev/tcp/${ip}/22" >/dev/null 2>&1
}

ping_ok() {
  local ip="$1"
  ping -c 1 -W 1 "$ip" >/dev/null 2>&1
}

usable_ip() {
  local ip="$1"
  is_ipv4 "$ip" || return 1
  port22_open "$ip" || ping_ok "$ip"
}

try_ip() {
  local ip="$1"
  local src="$2"
  if usable_ip "$ip"; then
    emit "$ip" "$src"
    exit 0
  fi
}

# 1) Explicit/default IP first.
if [[ -n "$DEFAULT_IP" ]]; then
  try_ip "$DEFAULT_IP" "default"
fi

# 2) mDNS/hostname resolution (useful after reboot/IP change).
if command -v getent >/dev/null 2>&1; then
  host_ip="$(getent ahostsv4 "$HOSTNAME_CANDIDATE" 2>/dev/null | awk '{print $1; exit}' || true)"
  if [[ -n "${host_ip:-}" ]]; then
    try_ip "$host_ip" "hostname"
  fi
fi

# 3) If OTA server has seen recent firmware/ingest traffic, reuse that IP.
if command -v docker >/dev/null 2>&1; then
  log_ip="$({
    docker logs "$OTA_SERVER_CONTAINER" --tail 800 2>/dev/null || true
  } | awk '
    match($0, /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) - - \[[^]]+\] "(GET \/firmware\/|POST \/ingest|POST \/) /, m) {
      ip = m[1]
    }
    END {
      if (ip != "") print ip
    }
  ')"
  if [[ -n "${log_ip:-}" ]]; then
    try_ip "$log_ip" "ota-server-log"
  fi
fi

# 4) Neighbor table scan inside configured subnet.
if command -v ip >/dev/null 2>&1; then
  while read -r cand; do
    [[ -n "$cand" ]] || continue
    try_ip "$cand" "ip-neigh"
  done < <(ip neigh 2>/dev/null | awk -v pfx="${SUBNET_PREFIX}." '$1 ~ "^" pfx {print $1}' | sort -u)
fi

# 5) Last-resort fallback (print valid default even if currently unreachable).
if is_ipv4 "$DEFAULT_IP"; then
  emit "$DEFAULT_IP" "fallback"
  exit 0
fi

echo "Could not resolve a Raspberry Pi IP" >&2
exit 1
