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
# Install SSH keys from Code Engine secrets
# --------------------------------------------------
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# VSI SSH Key (RSA)
VSI_KEY_FILE="$HOME/.ssh/id_rsa"
if [ -z "${id_rsa:-}" ]; then
  echo "ERROR: id_rsa environment variable is not set"
  exit 1
fi
echo "$id_rsa" > "$VSI_KEY_FILE"
chmod 600 "$VSI_KEY_FILE"
echo "VSI SSH key i
