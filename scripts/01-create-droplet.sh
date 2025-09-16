#!/usr/bin/env bash
set -euo pipefail

# Variables
SSH_KEY_NAME="FedericoRossi"
DROPLET_NAME="jenkins-server-agent-auto"
REGION="nyc3"
SIZE="s-1vcpu-2gb"
IMAGE="ubuntu-22-04-x64"

# 1. Obtener ID de la key
echo "[INFO] Buscando SSH Key ID para '${SSH_KEY_NAME}'..."
SSH_KEY_ID=$(doctl compute ssh-key list --output json | jq -r ".[] | select(.name==\"${SSH_KEY_NAME}\") | .id")

if [[ -z "$SSH_KEY_ID" ]]; then
  echo "[ERROR] No se encontró la key '${SSH_KEY_NAME}' en DigitalOcean"
  exit 1
fi
echo "[INFO] Key encontrada: ID=${SSH_KEY_ID}"

# 2. Crear droplet
echo "[INFO] Creando droplet '${DROPLET_NAME}'..."
doctl compute droplet create \
  --image "${IMAGE}" \
  --size "${SIZE}" \
  --region "${REGION}" \
  --ssh-keys "${SSH_KEY_ID}" \
  --wait \
  "${DROPLET_NAME}"

# 3. Obtener IP
DROPLET_IP=$(doctl compute droplet list "${DROPLET_NAME}" --format PublicIPv4 --no-header | tr -d '[:space:]')
echo "[INFO] Droplet '${DROPLET_NAME}' creado con IP: ${DROPLET_IP}"

# Output final
echo "${DROPLET_IP}"
