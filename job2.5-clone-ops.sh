#!/bin/bash
set -e  # Exit on error
set -x  # Enable debug mode - shows each command as it executes

echo "======================================"
echo "IBM Cloud & IBMi SSH Test Script"
echo "======================================"
echo ""

# IBM Cloud Authentication
readonly API_KEY="${IBMCLOUD_API_KEY}"
readonly REGION="us-south"
readonly RESOURCE_GROUP="Default"

# PowerVS Workspace Configuration
readonly PVS_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/db1a8b544a184fd7ac339c243684a9b7:973f4d55-9056-4848-8ed0-4592093161d2::"
readonly CLOUD_INSTANCE_ID="973f4d55-9056-4848-8ed0-4592093161d2"
readonly API_VERSION="2024-02-28"

# SSH Configuration
readonly VSI_HOST="52.118.255.179"
readonly VSI_USER="murphy"
readonly IBMI_HOST="192.168.0.109"
readonly IBMI_USER="murphy"

# Secret paths (mounted by Code Engine)
readonly VSI_KEY="/secrets/vsi/id_rsa"
readonly IBMI_KEY="/secrets/ibmi/id_rsa"
readonly IBMI_PASSWORD="${IBMI_PASSWORD}"  # Will be injected as env var from secret

# Create .ssh directory
echo "→ Setting up SSH environment..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Copy and set permissions on SSH keys
if [ -f "$VSI_KEY" ]; then
    echo "  ✓ Found VSI SSH key"
    cp "$VSI_KEY" ~/.ssh/vsi_key
    chmod 600 ~/.ssh/vsi_key
    ls -la ~/.ssh/vsi_key  # Show permissions for debugging
else
    echo "  ✗ ERROR: VSI SSH key not found at $VSI_KEY"
    exit 1
fi

if [ -f "$IBMI_KEY" ]; then
    echo "  ✓ Found IBMi SSH key"
    cp "$IBMI_KEY" ~/.ssh/ibmi_key
    chmod 600 ~/.ssh/ibmi_key
    ls -la ~/.ssh/ibmi_key  # Show permissions for debugging
else
    echo "  ✗ ERROR: IBMi SSH key not found at $IBMI_KEY"
    exit 1
fi

# Check if password is set
if [ -z "$IBMI_PASSWORD" ]; then
    echo "  ✗ ERROR: IBMi password not set"
    exit 1
else
    echo "  ✓ IBMi password is set (length: ${#IBMI_PASSWORD} chars)"
fi

echo ""
echo "======================================"
echo "STEP 1: IBM Cloud Authentication"
echo "======================================"
echo ""

echo "→ Authenticating to IBM Cloud (Region: ${REGION})..."
if ibmcloud login --apikey "$API_KEY" -r "$REGION"; then
    echo "✓ Authentication successful"
else
    echo "✗ ERROR: IBM Cloud login failed"
    exit 1
fi

echo ""
echo "→ Targeting resource group: ${RESOURCE_GROUP}..."
if ibmcloud target -g "$RESOURCE_GROUP"; then
    echo "✓ Resource group targeted"
else
    echo "✗ ERROR: Failed to target resource group"
    exit 1
fi

echo ""
echo "→ Targeting PowerVS workspace..."
if ibmcloud pi workspace target "$PVS_CRN"; then
    echo "✓ PowerVS workspace targeted"
else
    echo "✗ ERROR: Failed to target PowerVS workspace"
    exit 1
fi

echo ""
echo "======================================"
echo "STEP 2: Test VSI SSH Connection"
echo "======================================"
echo ""

echo "→ Testing SSH to VSI jump server..."
if ssh -i ~/.ssh/vsi_key \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    ${VSI_USER}@${VSI_HOST} \
    "echo 'VSI Connection Test: SUCCESS'; hostname; whoami"; then
    echo "✓ VSI connection successful"
else
    echo "✗ ERROR: Failed to connect to VSI"
    exit 1
fi

echo ""
echo "======================================"
echo "STEP 3: Test IBMi SSH Connection"
echo "======================================"
echo ""

echo "→ Testing SSH to IBMi through jump server..."
# Using sshpass to handle password authentication
if command -v sshpass &> /dev/null; then
    echo "  ✓ sshpass available"
    
    if sshpass -p "$IBMI_PASSWORD" ssh \
        -i ~/.ssh/vsi_key \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ProxyCommand="ssh -i ~/.ssh/vsi_key -W %h:%p -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${VSI_USER}@${VSI_HOST}" \
        -o ConnectTimeout=10 \
        ${IBMI_USER}@${IBMI_HOST} \
        "echo 'IBMi Connection Test: SUCCESS'; uname -a"; then
        echo "✓ IBMi connection successful"
    else
        echo "✗ ERROR: Failed to connect to IBMi"
        echo "  Troubleshooting: Check password, network, and SSH keys"
        exit 1
    fi
else
    echo "  ! sshpass not available, trying alternative method..."
    
    # Create expect script for password automation
    cat > /tmp/ssh_ibmi.exp <<'EXPECT_SCRIPT'
#!/usr/bin/expect -f
set timeout 30
set vsi_key [lindex $argv 0]
set vsi_user [lindex $argv 1]
set vsi_host [lindex $argv 2]
set ibmi_user [lindex $argv 3]
set ibmi_host [lindex $argv 4]
set ibmi_password [lindex $argv 5]

spawn ssh -i $vsi_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ${vsi_user}@${vsi_host} ${ibmi_user}@${ibmi_host}
expect {
    "password:" {
        send "${ibmi_password}\r"
        expect {
            "$" {
                send "echo 'IBMi Connection Test: SUCCESS'\r"
                send "uname -a\r"
                send "exit\r"
            }
            timeout {
                puts "ERROR: Timeout after password"
                exit 1
            }
        }
    }
    timeout {
        puts "ERROR: Connection timeout"
        exit 1
    }
}
expect eof
EXPECT_SCRIPT
    
    chmod +x /tmp/ssh_ibmi.exp
    
    if /tmp/ssh_ibmi.exp ~/.ssh/vsi_key $VSI_USER $VSI_HOST $IBMI_USER $IBMI_HOST "$IBMI_PASSWORD"; then
        echo "✓ IBMi connection successful"
    else
        echo "✗ ERROR: Failed to connect to IBMi"
        exit 1
    fi
fi

echo ""
echo "======================================"
echo "STEP 4: Run PASE Command on IBMi"
echo "======================================"
echo ""

echo "→ Executing PASE command: CALL PGM(QSYS/QAENGCHG) PARM(*ENABLECI)..."

# Create expect script for the full workflow
cat > /tmp/ibmi_pase_command.exp <<'EXPECT_SCRIPT'
#!/usr/bin/expect -f
set timeout 60
set vsi_key [lindex $argv 0]
set vsi_user [lindex $argv 1]
set vsi_host [lindex $argv 2]
set ibmi_user [lindex $argv 3]
set ibmi_host [lindex $argv 4]
set ibmi_password [lindex $argv 5]

log_user 1
puts "→ Connecting to IBMi..."

spawn ssh -i $vsi_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ${vsi_user}@${vsi_host} ${ibmi_user}@${ibmi_host}

expect {
    "password:" {
        puts "  ✓ Password prompt received"
        send "${ibmi_password}\r"
        exp_continue
    }
    -re "\\$|#|>" {
        puts "  ✓ Connected to IBMi shell"
        
        # Run the PASE command
        puts "→ Executing PASE command..."
        send "system \"CALL PGM(QSYS/QAENGCHG) PARM(*ENABLECI)\"\r"
        
        expect {
            -re "\\$|#|>" {
                puts "  ✓ PASE command executed"
                send "exit\r"
            }
            timeout {
                puts "  ✗ ERROR: PASE command timeout"
                exit 1
            }
        }
    }
    timeout {
        puts "  ✗ ERROR: Connection timeout"
        exit 1
    }
    eof {
        puts "  ✗ ERROR: Unexpected connection close"
        exit 1
    }
}

expect eof
puts "  ✓ Session closed"
EXPECT_SCRIPT

chmod +x /tmp/ibmi_pase_command.exp

if /tmp/ibmi_pase_command.exp ~/.ssh/vsi_key $VSI_USER $VSI_HOST $IBMI_USER $IBMI_HOST "$IBMI_PASSWORD"; then
    echo "✓ PASE command executed successfully"
else
    echo "✗ ERROR: Failed to execute PASE command"
    exit 1
fi

echo ""
echo "======================================"
echo "STEP 5: Run PowerVS Command"
echo "======================================"
echo ""

echo "→ Executing PowerVS volume clone command..."
if ibmcloud pi volume clone-async create wth \
    --volumes 9bc46eab-4b91-41de-beb8-5b677c7530a2,2f20f93c-c48c-4ab0-aa1d-6f5adac8d971; then
    echo "✓ PowerVS command executed successfully"
else
    echo "✗ ERROR: PowerVS command failed"
    exit 1
fi

echo ""
echo "======================================"
echo "ALL STEPS COMPLETED SUCCESSFULLY"
echo "======================================"
