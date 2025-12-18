#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# IBM Cloud Authentication
# -----------------------------
readonly API_KEY="${IBMCLOUD_API_KEY:?Missing IBMCLOUD_API_KEY}"
readonly REGION="us-south"
readonly RESOURCE_GROUP="Default"

# PowerVS Workspace Configuration
readonly PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"
readonly CLOUD_INSTANCE_ID="973f4d55-9056-4848-8ed0-4592093161d2"
readonly API_VERSION="2024-02-28"

# -----------------------------
# SSH / Host info
# -----------------------------
readonly VSI_USER="murphy"
readonly VSI_PUBLIC_IP="52.118.255.179"

readonly IBMI_USER="murphy"
readonly IBMI_PRIVATE_IP="192.168.0.109"

# -----------------------------
# Secrets / key paths (recommended: mount as files via Code Engine secret volumes)
#   Example paths below assume Code Engine mounts secrets into /secrets/...
# -----------------------------
readonly VSI_KEY_PATH="${VSI_SSH_KEY_PATH:-/secrets/vsi-ssh-mm}"     # private key file
readonly IBMI_KEY_PATH="${IBMI_SSH_KEY_PATH:-/secrets/ibmi-ssh-mm}"  # private key file

# Optional: IBM i password (only needed if key auth isn’t set up on IBM i)
readonly IBMI_PW="${IBMI_PW:-}"  # set via secret env var (e.g., ibmi-pw-mm)

echo "→ Authenticating to IBM Cloud (Region: ${REGION})..."
ibmcloud login --apikey "$API_KEY" -r "$REGION" >/dev/null 2>&1 || {
  echo "✗ ERROR: IBM Cloud login failed"
  exit 1
}
echo "✓ Authentication successful"

echo "→ Targeting resource group: ${RESOURCE_GROUP}..."
ibmcloud target -g "$RESOURCE_GROUP" >/dev/null 2>&1 || {
  echo "✗ ERROR: Failed to target resource group"
  exit 1
}
echo "✓ Resource group targeted"

echo "→ Targeting PowerVS workspace..."
ibmcloud pi workspace target "$PVS_CRN" >/dev/null 2>&1 || {
  echo "✗ ERROR: Failed to target PowerVS workspace"
  exit 1
}
echo "✓ PowerVS workspace targeted"

# Common SSH options for automation
SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile=/tmp/known_hosts
  -o ConnectTimeout=15
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
)

# Ensure key perms (some runtimes mount with permissive perms)
chmod 600 "$VSI_KEY_PATH" "$IBMI_KEY_PATH" 2>/dev/null || true

echo "→ Running IBM i PASE command via jump host..."
PASE_CMD='system "CALL PGM(QSYS/QAENGCHG) PARM(*ENABLECI)"'

# Preferred: key-based auth all the way (VSI key for jump, IBM i key for target)
if ssh -i "$VSI_KEY_PATH" "${SSH_OPTS[@]}" \
  -J "${VSI_USER}@${VSI_PUBLIC_IP}" \
  -i "$IBMI_KEY_PATH" \
  "${IBMI_USER}@${IBMI_PRIVATE_IP}" \
  "$PASE_CMD"
then
  echo "✓ PASE command executed successfully"
else
  echo "✗ ERROR: SSH/PASE command failed"
  exit 1
fi

echo "→ Running PowerVS volume clone async..."
# Use `ibmcloud` (your `ic` alias may not exist in Code Engine)
ibmcloud pi volume clone-async create wth \
  --volumes "9bc46eab-4b91-41de-beb8-5b677c7530a2,2f20f93c-c48c-4ab0-aa1d-6f5adac8d971"

echo "✓ Done"

