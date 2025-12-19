#!/usr/bin/env bash
set -euo pipefail

# ===========================================================
# IBM Cloud configuration
# ===========================================================
API_KEY="${IBMCLOUD_API_KEY}"
REGION="us-south"
RESOURCE_GROUP="Default"

PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"

# ===========================================================
# Host configuration
# ===========================================================
VSI_USER="murphy"
VSI_HOST="52.118.255.179"

IBMI_USER="murphy"
IBMI_HOST="192.168.0.109"

# ===========================================================
# SSH keys from env vars → temp files
# ===========================================================
VSI_KEY_FILE="$(mktemp)"
IBMI_KEY_FILE="$(mktemp)"

cleanup() {
  rm -f "$VSI_KEY_FILE" "$IBMI_KEY_FILE"
}
trap cleanup EXIT

echo "$VSI_SSH_KEY"  > "$VSI_KEY_FILE"
echo "$IBMI_SSH_KEY" > "$IBMI_KEY_FILE"

chmod 600 "$VSI_KEY_FILE" "$IBMI_KEY_FILE"

# ===========================================================
# SSH options (two-hop safe, Code Engine safe)
# ===========================================================
SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
  -o ConnectTimeout=15
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
  -o KexAlgorithms=+diffie-hellman-group14-sha1
)

# ===========================================================
# IBM Cloud login
# ===========================================================
echo "→ Authenticating to IBM Cloud..."
ibmcloud login --apikey "$API_KEY" -r "$REGION" >/dev/null
echo "✓ IBM Cloud authenticated"

sleep 5

echo "→ Targeting resource group..."
ibmcloud target -g "$RESOURCE_GROUP" >/dev/null

echo "→ Targeting PowerVS workspace..."
ibmcloud pi workspace target "$PVS_CRN" >/dev/null
echo "✓ PowerVS workspace targeted"

# ===========================================================
# SSH → VSI → IBM i → PASE command
# ===========================================================
echo "→ Running IBM i PASE command..."

if [[ -n "${IBMI_PW:-}" ]]; then
  # Password-capable path
  sshpass -p "$IBMI_PW" ssh \
    "${SSH_OPTS[@]}" \
    -o PreferredAuthentications=publickey,password \
    -o PubkeyAuthentication=yes \
    -o PasswordAuthentication=yes \
    -i "$VSI_KEY_FILE" \
    -J "${VSI_USER}@${VSI_HOST}" \
    -i "$IBMI_KEY_FILE" \
    "${IBMI_USER}@${IBMI_HOST}" \
    'system "CALL PGM(QSYS/QAENGCHG) PARM(*ENABLECI)"'
else
  # Key-only path
  ssh \
    "${SSH_OPTS[@]}" \
    -o BatchMode=yes \
    -i "$VSI_KEY_FILE" \
    -J "${VSI_USER}@${VSI_HOST}" \
    -i "$IBMI_KEY_FILE" \
    "${IBMI_USER}@${IBMI_HOST}" \
    'system "CALL PGM(QSYS/QAENGCHG) PARM(*ENABLECI)"'
fi

echo "✓ IBM i command completed"

sleep 5

# ===========================================================
# PowerVS operation
# ===========================================================
echo "→ Running PowerVS volume clone..."

ibmcloud pi volume clone-async create wth \
  --volumes "9bc46eab-4b91-41de-beb8-5b677c7530a2,2f20f93c-c48c-4ab0-aa1d-6f5adac8d971"

echo "✓ PowerVS clone submitted"
echo "✓ Job completed successfully"


