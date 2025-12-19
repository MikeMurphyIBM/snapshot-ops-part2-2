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
echo "VSI SSH key installed"

# IBMi SSH Key (ED25519)
IBMI_KEY_FILE="$HOME/.ssh/id_ed25519_vsi"
if [ -z "${id_ed25519_vsi:-}" ]; then
  echo "ERROR: id_ed25519_vsi environment variable is not set"
  exit 1
fi
echo "$id_ed25519_vsi" > "$IBMI_KEY_FILE"
chmod 600 "$IBMI_KEY_FILE"
echo "IBMi SSH key installed"

# --------------------------------------------------
# SSH to VSI, then to IBMi, run command
# --------------------------------------------------
echo "=== Connecting to IBMi via VSI ==="

ssh -i "$VSI_KEY_FILE" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  murphy@52.118.255.179 \
  "ssh -i /home/murphy/.ssh/id_ed25519_vsi \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       murphy@192.168.0.109 \
       'system \"CALL PGM(QSYS/QAENGCHG) PARM(*ENABLECI)\"'" || true

echo "IBMi command completed"
echo "Waiting 5 seconds before volume clone..."
sleep 5

# --------------------------------------------------
# Create volume clone in PowerVS
# --------------------------------------------------
echo "=== Creating volume clone ==="

ibmcloud pi volume clone-async create wth \
  --volumes 9bc46eab-4b91-41de-beb8-5b677c7530a2,2f20f93c-c48c-4ab0-aa1d-6f5adac8d971

echo "=== END JOB - ALL STEPS COMPLETED ==="
