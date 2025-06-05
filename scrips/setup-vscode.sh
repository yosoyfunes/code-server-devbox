#!/bin/bash
# Improved setup script for VS Code Server environment
# Designed to be run as a cron job for eventual consistency
# Uses actual verification of installed components instead of status files

# Enable error handling
set -e

# Setup logging
LOG_FILE="/var/log/setup-vscode.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

log() {
  echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

log_error() {
  echo "[$TIMESTAMP] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Create log file if it doesn't exist
touch "$LOG_FILE"
log "Starting VS Code setup script"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   log_error "This script must be run as root"
   exit 1
fi

# Install AWS CLI if not already installed or if outdated
if ! command -v aws &> /dev/null || [[ "$(aws --version 2>&1)" != *"aws-cli/2"* ]]; then
  log "Installing/updating AWS CLI..."
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl unzip zip
  curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip -o /tmp/aws-cli.zip
  unzip -q -d /tmp /tmp/aws-cli.zip
  /tmp/aws/install --update
  rm -rf /tmp/aws /tmp/aws-cli.zip
  log "AWS CLI installation completed: $(aws --version 2>&1)"
else
  log "AWS CLI already installed: $(aws --version 2>&1)"
fi

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
  log "Installing Docker..."
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
  
  # Check if Docker keyring already exists
  if [ ! -f "/usr/share/keyrings/docker-archive-keyring.gpg" ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  fi
  
  # Get Ubuntu version
  UBUNTU_VERSION=$(lsb_release -cs)
  
  # Check if Docker repo is already configured
  if [ ! -f "/etc/apt/sources.list.d/docker.list" ]; then
    echo "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $UBUNTU_VERSION stable" > /etc/apt/sources.list.d/docker.list
  fi
  
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io
  usermod -aG docker ubuntu
  log "Docker installation completed: $(docker --version 2>&1)"
else
  log "Docker already installed: $(docker --version 2>&1)"
fi

# Verify docker group membership for ubuntu user
if ! id -nG ubuntu | grep -qw "docker"; then
  log "Adding ubuntu user to docker group..."
  usermod -aG docker ubuntu
  newgrp docker
  log "Added ubuntu user to docker group"
else
  log "Ubuntu user already in docker group"
fi

# Install Git and configure
if ! command -v git &> /dev/null; then
  log "Installing Git..."
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common
  add-apt-repository -y ppa:git-core/ppa
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y git
  log "Git installation completed: $(git --version 2>&1)"
else
  log "Git already installed: $(git --version 2>&1)"
fi

# Configure Git if not already configured
if ! sudo -u ubuntu git config --global user.email >/dev/null 2>&1; then
  log "Configuring Git..."
  sudo -u ubuntu git config --global user.email "vscode@environment.net"
  sudo -u ubuntu git config --global user.name "VSCode Developer"
  sudo -u ubuntu git config --global init.defaultBranch "main"
  sudo -u ubuntu git config --global credential.helper store
  log "Git configuration completed"
else
  log "Git already configured"
fi

# Install Node.js if not already installed or if outdated
if ! command -v node &> /dev/null || [[ "$(node --version 2>&1)" != "v18"* ]]; then
  log "Installing Node.js..."
  
  # Get architecture
  ARCHITECTURE=$(dpkg --print-architecture)
  # Get Ubuntu version
  UBUNTU_VERSION=$(lsb_release -cs)
  # Node version
  NODE_VERSION="node_18.x"
  
  if [ ! -f "/usr/share/keyrings/nodesource-keyring.gpg" ]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource-keyring.gpg
  fi
  
  if [ ! -f "/etc/apt/sources.list.d/nodesource.list" ] || ! grep -q "$NODE_VERSION" /etc/apt/sources.list.d/nodesource.list; then
    echo "deb [arch=$ARCHITECTURE signed-by=/usr/share/keyrings/nodesource-keyring.gpg] https://deb.nodesource.com/$NODE_VERSION $UBUNTU_VERSION main" > /etc/apt/sources.list.d/nodesource.list
  fi
  
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  log "Node.js installation completed: $(node --version 2>&1)"
else
  log "Node.js already installed: $(node --version 2>&1)"
fi

# Install Python if not already installed
if ! command -v python3 &> /dev/null || ! dpkg -l | grep -q python3-pip || ! dpkg -l | grep -q python3-boto3 || ! dpkg -l | grep -q python3-pytest; then
  log "Installing Python and related packages..."
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3.10-venv python3-boto3 python3-pytest
  log "Python installation completed: $(python3 --version 2>&1)"
else
  log "Python already installed: $(python3 --version 2>&1)"
fi

# Add pytest alias if not already added
if ! grep -q "alias pytest=pytest-3" /home/ubuntu/.bashrc; then
  log "Adding pytest alias..."
  echo 'alias pytest=pytest-3' >> /home/ubuntu/.bashrc
  log "Added pytest alias"
else
  log "pytest alias already exists"
fi

# Install gitpython if not already installed
if ! sudo -u ubuntu pip3 list | grep -q gitpython; then
  log "Installing gitpython..."
  sudo -u ubuntu pip3 install gitpython
  log "gitpython installation completed"
else
  log "gitpython already installed"
fi

# Install git-remote-codecommit if not already installed
if ! pip3 list | grep -q git-remote-codecommit; then
  log "Installing git-remote-codecommit..."
  pip3 install git-remote-codecommit
  log "git-remote-codecommit installation completed"
else
  log "git-remote-codecommit already installed"
fi

# Update permissions
log "Updating permissions..."
mkdir -p /home/ubuntu/environment
chown ubuntu:ubuntu /home/ubuntu/environment -R

# Update environment variables
ENV_UPDATED=false

# Add environment variables if not already added
if ! grep -q "LANG=en_US.utf-8" /etc/environment; then
  log "Adding LANG to environment..."
  echo LANG=en_US.utf-8 >> /etc/environment
  ENV_UPDATED=true
fi

if ! grep -q "LC_ALL=en_US.UTF-8" /etc/environment; then
  log "Adding LC_ALL to environment..."
  echo LC_ALL=en_US.UTF-8 >> /etc/environment
  ENV_UPDATED=true
fi

# Update .bashrc if needed
if ! grep -q "PATH=\$PATH:/home/ubuntu/.local/bin" /home/ubuntu/.bashrc; then
  log "Adding local bin to PATH..."
  echo 'PATH=$PATH:/home/ubuntu/.local/bin' >> /home/ubuntu/.bashrc
  echo 'export PATH' >> /home/ubuntu/.bashrc
  ENV_UPDATED=true
fi

# Add AWS environment variables if not already added
if ! grep -q "export AWS_REGION=" /home/ubuntu/.bashrc; then
  log "Adding AWS_REGION to environment..."
  AWS_REGION=$(aws configure get region 2>/dev/null || echo "${AWS::Region}")
  echo "export AWS_REGION=$AWS_REGION" >> /home/ubuntu/.bashrc
  ENV_UPDATED=true
fi

if ! grep -q "export AWS_ACCOUNTID=" /home/ubuntu/.bashrc; then
  log "Adding AWS_ACCOUNTID to environment..."
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "${AWS::AccountId}")
  echo "export AWS_ACCOUNTID=$AWS_ACCOUNT_ID" >> /home/ubuntu/.bashrc
  ENV_UPDATED=true
fi

if ! grep -q "export NEXT_TELEMETRY_DISABLED=1" /home/ubuntu/.bashrc; then
  log "Adding NEXT_TELEMETRY_DISABLED to environment..."
  echo 'export NEXT_TELEMETRY_DISABLED=1' >> /home/ubuntu/.bashrc
  ENV_UPDATED=true
fi

if [ "$ENV_UPDATED" = true ]; then
  log "Environment settings updated"
else
  log "Environment settings already up to date"
fi

# Install VS Code Server if not already installed
if ! command -v code-server &> /dev/null; then
  log "Installing VS Code Server..."
  export HOME=/home/ubuntu
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
  curl -fsSL https://code-server.dev/install.sh | sh
  log "VS Code Server installation completed: $(code-server --version 2>&1)"
else
  log "VS Code Server already installed: $(code-server --version 2>&1)"
fi

# Install nginx if not already installed
if ! command -v nginx &> /dev/null; then
  log "Installing nginx..."
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
  log "nginx installation completed: $(nginx -v 2>&1)"
else
  log "nginx already installed: $(nginx -v 2>&1)"
fi

# Configure nginx for code-server
NGINX_CONFIG_UPDATED=false

# Get CloudFront domain name
#CLOUDFRONT_DOMAIN=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, 'vscode')].DomainName" --output text 2>/dev/null || echo "${CloudFrontDistributionVSCode.DomainName}")
# server_name ${CLOUDFRONT_DOMAIN};

# Check if nginx config exists and is correct
if [ ! -f "/etc/nginx/sites-available/code-server" ] || ! grep -q "$CLOUDFRONT_DOMAIN" /etc/nginx/sites-available/code-server; then
  log "Creating/updating nginx config for code-server..."
  
  # Create nginx config
  cat > /etc/nginx/sites-available/code-server <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name localhost;
    location ~ ^/(.*) {
        client_max_body_size 512M;
        proxy_pass http://localhost:8080;
        proxy_set_header Connection \$http_connection;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    location /app {
    proxy_pass http://localhost:8081/app;
    proxy_set_header Host \$host;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection upgrade;
    proxy_set_header Accept-Encoding gzip;
    }
}
EOF
  NGINX_CONFIG_UPDATED=true
else
  log "nginx config for code-server already exists and is correct"
fi

# Remove default nginx site configuration if it exists
if [ -f "/etc/nginx/sites-enabled/default" ]; then
  log "Removing default nginx site configuration..."
  rm -f /etc/nginx/sites-enabled/default
  NGINX_CONFIG_UPDATED=true
else
  log "Default nginx site configuration already removed"
fi

# Enable the site if not already enabled
if [ ! -L "/etc/nginx/sites-enabled/code-server" ]; then
  log "Enabling nginx site for code-server..."  
  ln -sf /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/code-server
  NGINX_CONFIG_UPDATED=true
else
  log "nginx site for code-server already enabled"
fi

# Configure code-server password
PASSWORD_CONFIG_UPDATED=false

# Create config directory if it doesn't exist
mkdir -p /home/ubuntu/.config/code-server/

# Check if config file exists and has password
if [ ! -f "/home/ubuntu/.config/code-server/config.yaml" ] || ! grep -q "hashed-password:" /home/ubuntu/.config/code-server/config.yaml; then
  log "Configuring code-server password..."
  
  # Get password from AWS Secrets Manager
  # PASSWORD=$(aws secretsmanager get-secret-value --secret-id vscode/CodeServer/user_credentials --query 'SecretString' --output text 2>/dev/null)  
  if [ -z "$PASSWORD" ]; then
    log_error "No password found in Secrets Manager, using default password"
    PASSWORD="devcontainer" # Default password for development purposes
  else
    log "Retrieved password from Secrets Manager"
  fi
  
  if [ -n "$PASSWORD" ]; then
    # Create config file
    cat > /home/ubuntu/.config/code-server/config.yaml <<EOF
cert: false
auth: password
hashed-password: "$(echo -n $PASSWORD | npx argon2-cli -e)"
EOF
    PASSWORD_CONFIG_UPDATED=true
  else
    log_error "Failed to retrieve password from Secrets Manager"
  fi
else
  log "Code-server password already configured"
fi

# Create directories and settings for code-server
SETTINGS_UPDATED=false
chown ubuntu:ubuntu /home/ubuntu -R

# Create directories
sudo -u ubuntu mkdir -p /home/ubuntu/.local/share/code-server/User/

# Check if settings file exists and has correct content
if [ ! -f "/home/ubuntu/.local/share/code-server/User/settings.json" ] || ! grep -q "terminal.integrated.cwd" /home/ubuntu/.local/share/code-server/User/settings.json; then
  log "Configuring code-server settings..."
  
  # Create settings file
  cat > /home/ubuntu/.local/share/code-server/User/settings.json <<EOF
{
"extensions.autoUpdate": true,
"extensions.autoCheckUpdates": true,
"terminal.integrated.cwd": "/home/ubuntu/environment",
"telemetry.telemetryLevel": "off",
"security.workspace.trust.startupPrompt": "never",
"security.workspace.trust.enabled": false,
"security.workspace.trust.banner": "never",
"security.workspace.trust.emptyWindow": false,
"editor.tabSize": 2,
"python.testing.pytestEnabled": true,
"auto-run-command.rules": [
    {
    "command": "workbench.action.terminal.new"
    }
],
"workbench.colorTheme": "Default Dark Modern",
"workbench.statusBar.visible": true,
"window.menuBarVisibility": "classic"
}
EOF
  
  chown ubuntu:ubuntu /home/ubuntu/.local/share/code-server/User/settings.json
  SETTINGS_UPDATED=true
else
  log "Code-server settings already configured"
fi

# Determine if we need to restart services
RESTART_NEEDED=false
if [ "$NGINX_CONFIG_UPDATED" = true ] || [ "$PASSWORD_CONFIG_UPDATED" = true ] || [ "$SETTINGS_UPDATED" = true ]; then
  RESTART_NEEDED=true
fi

# Restart services if needed
if [ "$RESTART_NEEDED" = true ]; then
  log "Restarting services..."
  systemctl restart code-server@ubuntu
  systemctl restart nginx
  log "Services restarted"
else
  log "No service restart needed"
fi

# Install extensions
EXTENSIONS_UPDATED=false

# Check if auto-run-command extension is installed
if ! sudo -u ubuntu --login code-server --list-extensions 2>/dev/null | grep -q "synedra.auto-run-command"; then
  log "Installing auto-run-command extension..."
  sudo -u ubuntu --login code-server --install-extension synedra.auto-run-command --force
  EXTENSIONS_UPDATED=true
else
  log "auto-run-command extension already installed"
fi

# Check if Amazon Q extension is installed
if ! sudo -u ubuntu --login code-server --list-extensions 2>/dev/null | grep -q "AmazonWebServices.amazon-q-vscode"; then
  log "Installing Amazon Q extension..."
  
  # Install dependencies
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl jq
  
  # Get latest Q extension URL
  Q_URL=$(curl -sL https://api.github.com/repos/aws/aws-toolkit-vscode/releases/latest | jq -r '.assets[] | select(.name? | match("amazon-q-vscode-[0-9].[0-9]*.[0-9]*.vsix$";"g")) | .browser_download_url')
  if [ -z "$Q_URL" ]; then
    log "No Q url found, using default"
    Q_URL=https://github.com/aws/aws-toolkit-vscode/releases/download/amazonq/v1.3.0/amazon-q-vscode-1.3.0.vsix
  fi
  
  log "Installing Amazon Q from: $Q_URL"
  curl -fsSL $Q_URL -o /tmp/AmazonWebServices.amazon-q-vscode.vsix
  sudo -u ubuntu --login code-server --install-extension /tmp/AmazonWebServices.amazon-q-vscode.vsix --force
  rm -f /tmp/AmazonWebServices.amazon-q-vscode.vsix
  
  touch /etc/vscode_complete_InstallQDeveloperExtension
  EXTENSIONS_UPDATED=true
else
  log "Amazon Q extension already installed"
fi

# Install Q CLI if not already installed
if ! command -v /usr/local/bin/q  &> /dev/null; then
  log "Installing Q CLI..."
  
  TMP_INSTALL_SH_FILE=$(mktemp)
  cat << '_EOF' > "${TMP_INSTALL_SH_FILE}"
#!/bin/bash

set -euo pipefail

echo "Installing Q CLI..."
TMPDIR=$(mktemp -d)
echo "Using temporary directory ${TMPDIR}"
curl --proto '=https' --tlsv1.2 -sSf "https://desktop-release.q.us-east-1.amazonaws.com/latest/q-x86_64-linux.zip" -o "${TMPDIR}/q.zip"

cat << 'EOF' > "${TMPDIR}/q-cli.pub"
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEZig60RYJKwYBBAHaRw8BAQdAy/+G05U5/EOA72WlcD4WkYn5SInri8pc4Z6D
BKNNGOm0JEFtYXpvbiBRIENMSSBUZWFtIDxxLWNsaUBhbWF6b24uY29tPoiZBBMW
CgBBFiEEmvYEF+gnQskUPgPsUNx6jcJMVmcFAmYoOtECGwMFCQPCZwAFCwkIBwIC
IgIGFQoJCAsCBBYCAwECHgcCF4AACgkQUNx6jcJMVmef5QD/QWWEGG/cOnbDnp68
SJXuFkwiNwlH2rPw9ZRIQMnfAS0A/0V6ZsGB4kOylBfc7CNfzRFGtovdBBgHqA6P
zQ/PNscGuDgEZig60RIKKwYBBAGXVQEFAQEHQC4qleONMBCq3+wJwbZSr0vbuRba
D1xr4wUPn4Avn4AnAwEIB4h+BBgWCgAmFiEEmvYEF+gnQskUPgPsUNx6jcJMVmcF
AmYoOtECGwwFCQPCZwAACgkQUNx6jcJMVmchMgEA6l3RveCM0YHAGQaSFMkguoAo
vK6FgOkDawgP0NPIP2oA/jIAO4gsAntuQgMOsPunEdDeji2t+AhV02+DQIsXZpoB
=f8yY
-----END PGP PUBLIC KEY BLOCK-----
EOF
gpg --no-default-keyring --keyring ~/.gnupg/trustedkeys.kbx --import "${TMPDIR}/q-cli.pub"
curl --proto '=https' --tlsv1.2 -sSf "https://desktop-release.q.us-east-1.amazonaws.com/latest/q-x86_64-linux.zip.sig" -o "${TMPDIR}/q.zip.sig"
gpgv "${TMPDIR}/q.zip.sig" "${TMPDIR}/q.zip"

unzip -d "${TMPDIR}" "${TMPDIR}/q.zip"
# Patch install.sh so it does not run `q setup` (which is interactive)
cat << 'EOF' > "${TMPDIR}/install.sh.patch"
143c143
<     /usr/local/bin/q setup --global "$@"
---
>     # /usr/local/bin/q setup --global "$@"
150c150
<     "$HOME/.local/bin/q" setup "$@"
---
>     # "$HOME/.local/bin/q" setup "$@"
EOF
patch "${TMPDIR}/q/install.sh" "${TMPDIR}/install.sh.patch"
"${TMPDIR}/q/install.sh"
echo "Completed installation of Q CLI."
_EOF
  chmod o+rx "${TMP_INSTALL_SH_FILE}"
  su - ubuntu -c "${TMP_INSTALL_SH_FILE}"
  rm -f "${TMP_INSTALL_SH_FILE}"
  
  log "Q CLI installation completed: $(/home/ubuntu/.local/bin/q --version 2>&1)"
else
  log "Q CLI already installed: $(/home/ubuntu/.local/bin/q --version 2>&1)"
fi

# Fix permissions
log "Fixing permissions..."
chown ubuntu:ubuntu /home/ubuntu -R

log "VS Code setup script completed successfully"
exit 0
