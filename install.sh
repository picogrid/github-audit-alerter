#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}GitHub Audit Alerter Installer${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo ./install.sh)${NC}"
  exit 1
fi

# 1. Locate Binary
BINARY_PATH="./github-audit-alerter"
if [ ! -f "$BINARY_PATH" ]; then
    echo "Binary not found in current directory."
    read -p "Enter path to github-audit-alerter binary: " USER_BINARY_PATH
    BINARY_PATH="$USER_BINARY_PATH"
fi

if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: Binary not found at $BINARY_PATH${NC}"
    exit 1
fi

# 2. Collect Configuration
echo ""
echo "--- Configuration ---"
read -p "GitHub Organization Name: " ORG_NAME
if [ -z "$ORG_NAME" ]; then
    echo -e "${RED}Organization name is required.${NC}"
    exit 1
fi

read -s -p "GitHub Personal Access Token (PAT): " GITHUB_TOKEN
echo ""
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}GitHub Token is required.${NC}"
    exit 1
fi

read -p "Slack Webhook URL (optional): " SLACK_WEBHOOK

# 3. Create User
echo ""
echo "--- Setting up User ---"
if id "github-audit" &>/dev/null; then
    echo "User 'github-audit' already exists."
else
    useradd -r -s /bin/false github-audit
    echo "Created user 'github-audit'."
fi

# 4. Install Binary
echo ""
echo "--- Installing Binary ---"
# Stop service if running to avoid "Text file busy"
systemctl stop github-audit-alerter 2>/dev/null || true

cp "$BINARY_PATH" /usr/local/bin/github-audit-alerter
chmod +x /usr/local/bin/github-audit-alerter
echo "Binary installed to /usr/local/bin/github-audit-alerter"

# 5. Create Config/Env File
echo ""
echo "--- Configuring Environment ---"
mkdir -p /etc/github-audit-alerter
cat > /etc/github-audit-alerter/env <<EOF
GITHUB_TOKEN=$GITHUB_TOKEN
GH_AUDIT_SLACK_WEBHOOK=$SLACK_WEBHOOK
EOF

# Set permissions (only root and service user can read)
chown -R root:github-audit /etc/github-audit-alerter
chmod 640 /etc/github-audit-alerter/env
echo "Environment secrets saved to /etc/github-audit-alerter/env"

# 6. Create Systemd Service
echo ""
echo "--- Creating Systemd Service ---"
cat > /etc/systemd/system/github-audit-alerter.service <<EOF
[Unit]
Description=GitHub Audit Alerter Service
After=network.target

[Service]
Type=simple
User=github-audit
Group=github-audit
# Load environment variables
EnvironmentFile=/etc/github-audit-alerter/env
# Run the binary with flags
ExecStart=/usr/local/bin/github-audit-alerter \\
    --org ${ORG_NAME} \\
    --max-repos-cloned-per-user 5 \\
    --interval 15m

# Restart automatically if it crashes
Restart=always
RestartSec=10s

# Security hardening
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF

echo "Service definition created at /etc/systemd/system/github-audit-alerter.service"

# 7. Enable and Start
echo ""
echo "--- Starting Service ---"
systemctl daemon-reload
systemctl enable github-audit-alerter
systemctl restart github-audit-alerter

if systemctl is-active --quiet github-audit-alerter; then
    echo -e "${GREEN}Success! github-audit-alerter is now running.${NC}"
    echo "Check logs with: journalctl -u github-audit-alerter -f"
else
    echo -e "${RED}Warning: Service failed to start immediately.${NC}"
    echo "Check status with: systemctl status github-audit-alerter"
    echo "Check logs with: journalctl -u github-audit-alerter"
fi
