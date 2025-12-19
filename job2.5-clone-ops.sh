#!/usr/bin/env bash
set -euo pipefail

echo "=== START JOB ==="

# ===========================================================
# VARIABLES (Code Engine environment variables)
# ===========================================================
API_KEY="${IBMCLOUD_API_KEY}"

# SSH secrets (MUST be multiline, exactly as pasted)
VSI_SSH_KEY="${vsi_ssh}"

# ===========================================================
# STATIC CONFIG
# ===========================================================
REGION="us-south"
RESOURCE_GROUP="Default"

PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"

VSI_USER="murphy"
VSI_HOST="52.118.255.179"

# ===========================================================
# WRITE SSH KEY SAFELY
# ===========================================================
VSI_KEY_FILE="$(mktemp)"

cleanup() {
  rm -f "$VSI_KEY_FILE"
}
trap cleanup EXIT

# IMPORTANT: printf preserves newlines correctly
printf '%s\n' "$VSI_SSH_KEY" > "$VSI_KEY_FILE"
chmod 600 "$VSI_KEY_FILE"

echo "SSH key written"

echo "=== VALIDATING SSH PRIVATE KEY ==="

ls -l "$VSI_KEY_FILE"

echo "--- First line of key ---"
head -1 "$VSI_KEY_FILE"

echo "--- Last line of key ---"
tail -1 "$VSI_KEY_FILE"

echo "--- ssh-keygen validation ---"
if ssh-keygen -y -f "$VSI_KEY_FILE" >/dev/null 2>&1; then
  echo "✅ SSH private key is VALID"
else
  echo "❌ SSH private key is INVALID"
  exit 1
fi


# Sanity check – fail early if key is invalid
ssh-keygen -y -f "$VSI_KEY_FILE" >/dev/null
echo "SSH key validated"

# ===========================================================
# IBM Cloud Login
# ===========================================================
echo "Logging into IBM Cloud..."
ibmcloud login --apikey "$API_KEY" -r "$REGION" >/dev/null
echo "IBM Cloud login OK"

echo "Targeting resource group..."
ibmcloud target -g "$RESOURCE_GROUP" >/dev/null
echo "Resource group targeted"

echo "Targeting PowerVS workspace..."
ibmcloud pi workspace target "$PVS_CRN" >/dev/null
echo "PowerVS workspace targeted"

# ===========================================================
# SSH → VSI (TEST ONLY)
# ===========================================================
echo "=== SSH: Code Engine → VSI ==="

ssh -vv \
  -i "$VSI_KEY_FILE" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o GlobalKnownHostsFile=/dev/null \
  -o IdentitiesOnly=yes \
  -o ConnectTimeout=15 \
  "${VSI_USER}@${VSI_HOST}" \
  "echo 'SSH to VSI SUCCESS'"

echo "=== JOB COMPLETE ==="
