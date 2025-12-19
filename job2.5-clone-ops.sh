#!/usr/bin/env bash
set -euo pipefail

echo "=== START JOB ==="

### 1. Prepare SSH directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

### 2. Write SSH key from env var to file (NO ECHO)
KEY_FILE="/root/.ssh/id_ed25519"

if [[ -z "${vsi_ssh:-}" ]]; then
  echo "ERROR: vsi_ssh environment variable is not set"
  exit 1
fi

printf '%s\n' "$vsi_ssh" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

### 3. Sanity check (safe)
ssh-keygen -l -f "$KEY_FILE" >/dev/null

echo "SSH key installed correctly"

### 4. SSH to VSI
ssh \
  -o StrictHostKeyChecking=no \
  -i "$KEY_FILE" \
  murphy@52.118.255.179 \
  "echo 'Connected to VSI OK'"

echo "=== JOB COMPLETE ==="

