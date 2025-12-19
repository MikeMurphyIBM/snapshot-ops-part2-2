#!/usr/bin/env bash
set -euo pipefail

echo "=== START JOB ==="

# --------------------------------------------------
# IBM Cloud authentication
# --------------------------------------------------
API_KEY="${IBMCLOUD_API_KEY}"
REGION="us-south"
RESOURCE_GROUP="Default"

PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"

echo "Logging into IBM Cloud..."
ibmcloud login --apikey "$API_KEY" -r "$REGION" >/dev/null
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
KEY_FILE="$(mktemp)"
chmod 600 "$KEY_FILE"

# 'vsi_ssh' is injected by Code Engine:
# vsi_ssh -> vsi-ssh.id_rsa
printf '%s\n' "$vsi_ssh" > "$KEY_FILE"

echo "SSH key installed correctly"

# --------------------------------------------------
# SSH to VSI
# --------------------------------------------------
ssh \
  -i "$KEY_FILE" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  murphy@52.118.255.179 \
  "echo 'Logged into VSI successfully'"

echo "=== END JOB ==="

