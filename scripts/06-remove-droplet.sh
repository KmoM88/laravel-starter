#!/bin/bash
set -euo pipefail

# Nombre del droplet a eliminar
DROPLET_NAME="$1"

if [[ -z "$DROPLET_NAME" ]]; then
  echo "❌ Debes pasar el nombre del droplet como argumento"
  echo "Uso: $0 <droplet-name>"
  exit 1
fi

# Obtener el ID del droplet por nombre
DROPLET_ID=$(doctl compute droplet list --no-header --format ID,Name | awk -v name="$DROPLET_NAME" '$2 == name {print $1}')

if [[ -z "$DROPLET_ID" ]]; then
  echo "⚠️ No se encontró un droplet con el nombre: $DROPLET_NAME"
  exit 0
fi

echo "🗑 Eliminando droplet '$DROPLET_NAME' (ID: $DROPLET_ID)..."
doctl compute droplet delete -f "$DROPLET_ID"

echo "✅ Droplet '$DROPLET_NAME' eliminado correctamente."
