#!/usr/bin/env bash
set -euo pipefail

echo "=== START JOB ==="

# -----------------------------------------------------------
# IBM Cloud configuration
# -----------------------------------------------------------
REGION="us-south"
RESOURCE_GROUP="Default"
PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"

# -----------------------------------------------------------
# IBM Cloud login + targeting
# -----------------------------------------------------------
echo "Logging into IBM Cloud..."
ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$REGION" >/dev/null
echo "IBM Cloud login OK"

echo "Targeting resource group..."
ibmcloud target -g "$RESOURCE_GROUP" >/dev/null
echo "Resource group targeted"

echo "Targeting PowerVS workspace..."
ibmcloud pi workspace target "$PVS_CRN" >/dev/null
echo "PowerVS workspace targeted"

# -----------------------------------------------------------
# Write SSH keys to temp files
# -----------------------------------------------------------
VSI_KEY_FILE="$(mktemp)"
IBMI_KEY_FILE="$(mktemp)"

cleanup() {
  rm -f "$VSI_KEY_FILE" "$IBMI_KEY_FILE"
}
trap cleanup EXIT

echo "$vsi_ssh"  > "$VSI_KEY_FILE"
echo "$ibmi_ssh" > "$IBMI_KEY_FILE"

chmod 600 "$VSI_KEY_FILE" "$IBMI_KEY_FILE"

echo "SSH keys written"

# -----------------------------------------------------------
# STEP 1: SSH into VSI
# -----------------------------------------------------------
echo "=== SSH: Code Engine → VSI ==="

ssh \
  -vv \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o GlobalKnownHostsFile=/dev/null \
  -i "$VSI_KEY_FILE" \
  murphy@52.118.255.179 << 'EOF'

echo "ON VSI"

# -----------------------------------------------------------
# STEP 2: SSH from VSI → IBM i
# -----------------------------------------------------------
echo "=== SSH: VSI → IBM i ==="

ssh \
  -vv \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o GlobalKnownHostsFile=/dev/null \
  -o KexAlgorithms=+diffie-hellman-group14-sha1 \
  murphy@192.168.0.109 \
  'system "CALL PGM(QSYS/QAENGCHG) PARM(*ENABLECI)"'

echo "IBM i command finished"

EOF

echo "=== JOB COMPLETE ==="



