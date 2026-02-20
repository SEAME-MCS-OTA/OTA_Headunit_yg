#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-/work/keys}"
mkdir -p "${OUT_DIR}"

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out "${OUT_DIR}/rauc.key.pem"
openssl req -x509 -new -nodes -key "${OUT_DIR}/rauc.key.pem" -sha256 -days 3650 \
  -subj "/C=DE/O=IVI Head Unit/OU=OTA/CN=ivi-rauc" \
  -out "${OUT_DIR}/rauc.cert.pem"

chmod 600 "${OUT_DIR}/rauc.key.pem"

printf "Generated:\n- %s\n- %s\n" "${OUT_DIR}/rauc.key.pem" "${OUT_DIR}/rauc.cert.pem"
