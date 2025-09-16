#!/usr/bin/env bash
set -euo pipefail

# Variables
DROPLET_NAME="jenkins-server-agent-auto"
SSH_USER="root"
SSH_KEY_FILE="${HOME}/.ssh/id_rsa"   # Ajusta si usás otra clave
DOCKERFILE_PATH="docker-compose/Dockerfile.jenkins"

# 1. Obtener IP del droplet
echo "[INFO] Buscando IP del droplet '${DROPLET_NAME}'..."
DROPLET_IP=$(doctl compute droplet list "${DROPLET_NAME}" --format PublicIPv4 --no-header | tr -d '[:space:]')

if [[ -z "${DROPLET_IP}" ]]; then
  echo "[ERROR] No se encontró un droplet con el nombre '${DROPLET_NAME}'"
  exit 1
fi
echo "[INFO] IP encontrada: ${DROPLET_IP}"

# 2. Copiar Dockerfile al droplet
echo "[INFO] Copiando Dockerfile.jenkins al droplet..."
scp -i "${SSH_KEY_FILE}" -o StrictHostKeyChecking=no \
    "${DOCKERFILE_PATH}" \
    "${SSH_USER}@${DROPLET_IP}:/root/Dockerfile.jenkins"

# 3. Construir y correr Jenkins en el droplet
echo "[INFO] Construyendo imagen y levantando contenedor Jenkins..."
ssh -i "${SSH_KEY_FILE}" -o StrictHostKeyChecking=no "${SSH_USER}@${DROPLET_IP}" bash <<'EOF'
  set -euo pipefail

  echo "[REMOTE] Limpiando contenedor viejo (si existe)..."
  docker stop jenkins || true
  docker rm jenkins || true

  echo "[REMOTE] Construyendo imagen..."
  docker build -t jenkins-tierone -f Dockerfile.jenkins .

  echo "[REMOTE] Levantando contenedor Jenkins..."
  docker run -d \
    --name jenkins \
    -u root \
    -p 8080:8080 -p 50000:50000 \
    -v /var/jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    jenkins-tierone:latest

  echo "[REMOTE] ✅ Jenkins desplegado en http://$(hostname -I | awk '{print $1}'):8080"
EOF

echo "[INFO] 🎉 Jenkins desplegado en droplet ${DROPLET_IP} (http://${DROPLET_IP}:8080)"
