#!/usr/bin/env bash
set -euo pipefail

# Variables
DROPLET_NAME="jenkins-server-agent-auto"
SSH_USER="root"
SSH_KEY_FILE="${HOME}/.ssh/id_rsa"  # Ajusta si usás otra clave
MAX_RETRIES=30
WAIT_SEC=10

# 1. Obtener IP del droplet
echo "[INFO] Buscando IP del droplet '${DROPLET_NAME}'..."
DROPLET_IP=$(doctl compute droplet list "${DROPLET_NAME}" --format PublicIPv4 --no-header | tr -d '[:space:]')

if [[ -z "${DROPLET_IP}" ]]; then
  echo "[ERROR] No se encontró un droplet con el nombre '${DROPLET_NAME}'"
  exit 1
fi
echo "[INFO] IP encontrada: ${DROPLET_IP}"

# 2. Esperar que acepte SSH
echo "[INFO] Esperando a que ${DROPLET_IP} acepte conexiones SSH..."
reachable=false
for ((i=1; i<=MAX_RETRIES; i++)); do
  if ssh -i "${SSH_KEY_FILE}" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
       "${SSH_USER}@${DROPLET_IP}" "echo OK" &>/dev/null; then
    reachable=true
    echo "[INFO] Droplet disponible después de ${i} intentos."
    break
  else
    echo "[WARN] Intento ${i}: droplet no disponible aún. Esperando ${WAIT_SEC} segundos..."
    sleep "${WAIT_SEC}"
  fi
done

if [[ "$reachable" != true ]]; then
  echo "[ERROR] No se pudo conectar al droplet después de ${MAX_RETRIES} intentos."
  exit 1
fi

# 3. Instalar Docker
echo "[INFO] Instalando Docker en el droplet..."
ssh -i "${SSH_KEY_FILE}" -o StrictHostKeyChecking=no "${SSH_USER}@${DROPLET_IP}" bash <<'EOF'
  set -euo pipefail

  echo "[REMOTE] Verificando si apt está bloqueado..."
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "[REMOTE] Esperando que se libere el lock de apt..."
    sleep 5
  done

  echo "[REMOTE] Actualizando e instalando dependencias..."
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

  echo "[REMOTE] Agregando repositorio de Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --batch -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu jammy stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  echo "[REMOTE] Instalando Docker..."
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io

  echo "[REMOTE] Habilitando y arrancando Docker..."
  systemctl enable docker
  systemctl start docker

  echo "[REMOTE] ✅ Docker instalado correctamente."
EOF

echo "[INFO] 🎉 Droplet ${DROPLET_IP} listo con Docker instalado."
