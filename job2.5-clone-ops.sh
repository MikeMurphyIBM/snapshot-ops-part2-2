#!/usr/bin/env bash
set -euo pipefail

echo "=== START JOB ==="

# =========================================================
# IBM Cloud configuration
# =========================================================
IBMCLOUD_API_KEY="${IBMCLOUD_API_KEY}"
REGION="us-south"
RESOURCE_GROUP="Default"

PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"

# =========================================================
# SSH configuration
# =========================================================
VSI_USER="murphy"
VSI_HOST="52.118.255.179"

IBMI_USER="murphy"
IBMI_HOST="192.168.0.109"

# =========================================================
# SSH key (mounted secret)
# =========================================================
VSI_KEY="/secrets/vsi/id_ed25519"

# Fail fast if key is missing
if [[ ! -f "$VSI_KEY" ]]; then
  echo "ERROR: SSH key not found at $VSI_KEY"
  exit 1
fi

chmod 600 "$VSI_KEY"

# =========================================================
# IBM Cloud login & targeting
# =========================================================
echo "→ Logging into IBM Cloud..."
ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$REGION" >/dev/null
echo "✓ IBM Cloud login OK"

echo "→ Targeting resource group..."
ibmcloud target -g "$RESOURCE_GROUP" >/dev/null
echo "✓ Resource group targeted"

echo "→ Targeting PowerVS workspace..."
ibmcloud pi workspace target "$PVS_CRN" >/dev/null
echo "✓ PowerVS workspace targeted"

# =========================================================
# SSH: Code Engine → VSI → IBM i
# =========================================================
echo "→ SSH: Code Engine → VSI"

ssh \
  -i "$VSI_KEY" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o GlobalKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${VSI_USER}@${VSI_HOST}" << 'EOF'

set -euo pipefail

echo "✓ Logged into VSI"

echo "→ SSH: VSI → IBM i"

ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o GlobalKnownHostsFile=/dev/null \
  murphy@192.168.0.109 \
  'system "DSPJOB"'

echo "✓ IBM i command completed"
