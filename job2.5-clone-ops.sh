#!/usr/bin/env bash
set -euo pipefail
echo "=== START JOB ==="

# --------------------------------------------------
# IBM Cloud authentication
# --------------------------------------------------
REGION="us-south"
RESOURCE_GROUP="Default"
PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"

echo "Logging into IBM Cloud..."
ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$REGION" >/dev/null
echo "IBM Cloud login OK"

echo "Targeting resource group..."
ibmcloud target -g "$RESOURCE_GROUP" >/dev/null
echo "Resource group targeted"

echo "Targeting PowerVS workspace..."
ibmcloud pi workspace target "$PVS_CRN" >/dev/null
echo "PowerVS workspace targeted"

# --------------------------------------------------
# Install SSH key from Code Engine secret
# --------------------------------------------------
KEY_FILE="$HOME/.ssh/id_rsa"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Validate the secret exists
if [ -z "${vsi_ssh:-}" ]; then
  echo "ERROR: vsi_ssh environment variable is not set"
  echo "Check that the secret is properly configured in Code Engine"
  exit 1
fi

echo "Installing SSH key..."

# Check if the key is base64 encoded or plain text
if echo "$vsi_ssh" | head -n 1 | grep -q "BEGIN.*PRIVATE KEY"; then
  # It's plain text (not base64 encoded)
  echo "Key is in plain text format"
  echo "$vsi_ssh" > "$KEY_FILE"
else
  # It's base64 encoded - decode it
  echo "Key is base64 encoded, decoding..."
  if ! echo "$vsi_ssh" | tr -d '[:space:]' | base64 -d > "$KEY_FILE" 2>/dev/null; then
    echo "ERROR: Failed to decode base64 SSH key"
    exit 1
  fi
fi

chmod 600 "$KEY_FILE"

# Verify the key looks valid
if ! grep -q "BEGIN.*PRIVATE KEY" "$KEY_FILE"; then
  echo "ERROR: Decoded key doesn't look like a valid SSH private key"
  head -n 2 "$KEY_FILE"
  exit 1
fi

echo "SSH key installed successfully"

# --------------------------------------------------
# SSH to VSI
# --------------------------------------------------
echo "Connecting to VSI..."
ssh \
  -i "$KEY_FILE" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  murphy@52.118.255.179 \
  "echo 'Logged into VSI successfully'"

echo "=== END JOB ==="
