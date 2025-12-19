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

if [ -z "${id_rsa:-}" ]; then
  echo "ERROR: id_rsa environment variable is not set"
  exit 1
fi

echo "Installing SSH key..."
echo "$id_rsa" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

if grep -q "BEGIN.*PRIVATE KEY" "$KEY_FILE"; then
  echo "SSH key installed successfully"
else
  echo "ERROR: Key doesn't look like a valid SSH private key"
  exit 1
fi

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
