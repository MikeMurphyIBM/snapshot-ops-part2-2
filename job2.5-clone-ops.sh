#!/usr/bin/env bash
set -euo pipefail

# ===========================================================
# IBM Cloud Authentication
# ===========================================================
readonly API_KEY="${IBMCLOUD_API_KEY}"
readonly REGION="us-south"
readonly RESOURCE_GROUP="Default"

# PowerVS Workspace Configuration
readonly PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"
readonly CLOUD_INSTANCE_ID="973f4d55-9056-4848-8ed0-4592093161d2"
readonly API_VERSION="2024-02-28"

# ===========================================================
# SSH / Host Configuration
# ===========================================================
readonly VSI_USER="murphy"
readonly VSI_PUBLIC_IP="52.118.255.179"

readonly IBMI_USER="murphy"
readonly IBMI_PRIVATE_IP="192.168.0.109"

# ===========================================================
# SSH Keys (injected as env vars from Code Engine secrets)
# ===========================================================
readonly VSI_SSH_KEY="${vsi_ssh_mm}"
readonly IBMI_SSH_KEY="${ibmi_ssh_mm}"


VSI_KEY_FILE="$(mktemp)"
IBMI_KEY_FILE="$(mktemp)"

cleanup() {
  rm -f "$VSI_KEY_FILE" "$IBMI_KEY_FILE"
}
trap cleanup EXIT

echo "$VSI_SSH_KEY" > "$VSI_KEY_FILE"
echo "$IBMI_SSH_KEY" > "$IBMI_KEY_FILE"

chmod 600 "$VSI_KEY_FILE" "$IBMI_KEY_FILE"

# ===========================================================
# SSH Options (Code Engine + IBM i compatible)
# ===========================================================
SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
  -o ConnectTimeout=15
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
  -o KexAlgorithms=+diffie-hellman-group14-sha1
)


# ===========================================================
# IBM Cloud Login
# ===========================================================
echo "→ Authenticating to IBM Cloud (Region: ${REGION})..."
ibmcloud login --apikey "$API_KEY" -r "$REGION" >/dev/null 2>&1
echo "✓ Authentication successful"

echo "→ Waiting 5 seconds after IBM Cloud authentication..."
sleep 5

echo "→ Targeting resource group: ${RESOURCE_GROUP}..."
ibmcloud target -g "$RESOURCE_GROUP" >/dev/null 2>&1
echo "✓ Resource group targeted"

echo "→ Targeting PowerVS workspace..."
ibmcloud pi workspace target "$PVS_CRN" >/dev/null 2>&1
echo "✓ PowerVS workspace targeted"

# ===========================================================
# SSH → IBM i → PASE Command
# ===========================================================
echo "→ Running IBM i PASE command via VSI jump host..."

ssh \
  -i "$VSI_KEY_FILE" \
  "${SSH_OPTS[@]}" \
  -J "${VSI_USER}@${VSI_PUBLIC_IP}" \
  -i "$IBMI_KEY_FILE" \
  "${IBMI_USER}@${IBMI_PRIVATE_IP}" \
  'system "CALL PGM(QSYS/QAENGCHG) PARM(*ENABLECI)"'

echo "✓ IBM i PASE command completed"

echo "→ Waiting 5 seconds after IBM i login..."
sleep 5

echo "→ Exiting IBM i session"

echo "→ Waiting 5 seconds after IBM i exit..."
sleep 5

# ===========================================================
# PowerVS Command (still authenticated)
# ===========================================================
echo "→ Running PowerVS volume clone async..."

ibmcloud pi volume clone-async create wth \
  --volumes "9bc46eab-4b91-41de-beb8-5b677c7530a2,2f20f93c-c48c-4ab0-aa1d-6f5adac8d971"

echo "✓ PowerVS volume clone command submitted"
echo "✓ Job completed successfully"


