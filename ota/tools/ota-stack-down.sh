#!/usr/bin/env bash
set -euo pipefail

# Script location: <repo>/ota/tools
# Use repository root for compose path.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.ota-stack.yml"

cd "${ROOT_DIR}"
docker compose -f "${COMPOSE_FILE}" down
