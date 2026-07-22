#!/usr/bin/env bash
# =============================================================================
# 5eTools — Standalone Proxmox LXC Installer
# =============================================================================
# A self-contained alternative to the community-scripts split pair.
# Run this from the Proxmox host shell:
#
#   bash 5etools-standalone.sh
#
# It creates an LXC container, installs Node.js + git, clones 5eTools from
# GitHub, and starts a systemd service on port 5050.
# =============================================================================
# Source:  https://github.com/5etools-mirror-3/5etools-src
# License: MIT
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
RD=$(echo "\033[01;31m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD=" "
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

msg_info()  { local msg="$1"; echo -ne " ${HOLD} ${YW}${msg}...${CL}"; }
msg_ok()    { local msg="$1"; echo -e "${BFR} ${CM} ${GN}${msg}${CL}"; }
msg_error() { local msg="$1"; echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"; }

# ---------------------------------------------------------------------------
# Default container settings  (edit these if you need more resources)
# ---------------------------------------------------------------------------
CT_ID="${1:-$(pvesh get /cluster/nextid)}"
CT_HOSTNAME="5etools"
CT_PASSWORD="$(openssl rand -base64 12)"
CT_STORAGE="local-lvm"
CT_DISK="20"          # GB — source repo is ~1 GB; images add ~7 GB
CT_RAM="2048"         # MB
CT_CPU="2"
CT_BRIDGE="vmbr0"
CT_OS_TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
CT_OS_STORAGE="local"
SERVE_PORT="5050"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  msg_error "This script must be run as root on the Proxmox host"
  exit 1
fi

if ! command -v pct &>/dev/null; then
  msg_error "pct not found — are you running this on a Proxmox VE host?"
  exit 1
fi

echo -e "
  ____  ___  _____           _
 | ___|/ _ \|_   _|__   ___ | |___
 |___ \ (_) | | |/ _ \ / _ \| / __|
  ___) \__, | | | (_) | (_) | \__ \\
 |____/  /_/  |_|\___/ \___/|_|___/
 
  Local 5eTools — Proxmox LXC Installer
"

echo -e " ${YW}Container ID  :${CL} ${CT_ID}"
echo -e " ${YW}Hostname      :${CL} ${CT_HOSTNAME}"
echo -e " ${YW}RAM           :${CL} ${CT_RAM} MB"
echo -e " ${YW}CPU           :${CL} ${CT_CPU} cores"
echo -e " ${YW}Disk          :${CL} ${CT_DISK} GB"
echo -e " ${YW}Bridge        :${CL} ${CT_BRIDGE}"
echo -e " ${YW}Serve port    :${CL} ${SERVE_PORT}"
echo ""

read -rp " Proceed with installation? [y/N] " CONFIRM
[[ "${CONFIRM,,}" != "y" ]] && { echo "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
# Download OS template if not already present
# ---------------------------------------------------------------------------
msg_info "Checking for Debian 12 template"
TEMPLATE_PATH=$(pveam list ${CT_OS_STORAGE} 2>/dev/null \
  | grep -m1 "${CT_OS_TEMPLATE}" | awk '{print $1}' || true)

if [[ -z "${TEMPLATE_PATH}" ]]; then
  msg_info "Downloading Debian 12 template"
  pveam update &>/dev/null
  pveam download "${CT_OS_STORAGE}" "${CT_OS_TEMPLATE}" &>/dev/null
  TEMPLATE_PATH="${CT_OS_STORAGE}:vztmpl/${CT_OS_TEMPLATE}"
  msg_ok "Downloaded Debian 12 template"
else
  msg_ok "Debian 12 template already present"
fi

# ---------------------------------------------------------------------------
# Create the LXC container
# ---------------------------------------------------------------------------
msg_info "Creating LXC container ${CT_ID}"
pct create "${CT_ID}" "${TEMPLATE_PATH}" \
  --hostname "${CT_HOSTNAME}" \
  --password "${CT_PASSWORD}" \
  --storage "${CT_STORAGE}" \
  --rootfs "${CT_STORAGE}:${CT_DISK}" \
  --memory "${CT_RAM}" \
  --cores "${CT_CPU}" \
  --net0 "name=eth0,bridge=${CT_BRIDGE},ip=dhcp,ip6=auto" \
  --features "nesting=1" \
  --unprivileged 1 \
  --start 0 \
  &>/dev/null
msg_ok "Created LXC container ${CT_ID}"

# ---------------------------------------------------------------------------
# Start container and wait for it to be ready
# ---------------------------------------------------------------------------
msg_info "Starting container"
pct start "${CT_ID}" &>/dev/null
sleep 5
msg_ok "Container started"

# ---------------------------------------------------------------------------
# Helper: run a command inside the container
# ---------------------------------------------------------------------------
pct_exec() { pct exec "${CT_ID}" -- bash -c "$*"; }

# ---------------------------------------------------------------------------
# Update OS
# ---------------------------------------------------------------------------
msg_info "Updating container OS"
pct_exec "apt-get update -qq && apt-get upgrade -y -qq" &>/dev/null
msg_ok "Updated container OS"

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
msg_info "Installing git, curl, and ca-certificates"
pct_exec "apt-get install -y -qq git curl ca-certificates gnupg" &>/dev/null
msg_ok "Installed base dependencies"

# ---------------------------------------------------------------------------
# Install Node.js 22.x
# ---------------------------------------------------------------------------
msg_info "Installing Node.js 22.x"
pct_exec "
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main' \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update -qq
  apt-get install -y -qq nodejs
" &>/dev/null
NODE_VER=$(pct_exec "node -v" 2>/dev/null || echo "unknown")
msg_ok "Installed Node.js ${NODE_VER}"

# ---------------------------------------------------------------------------
# Clone 5eTools source
# ---------------------------------------------------------------------------
msg_info "Cloning 5eTools source from GitHub (may take a few minutes)"
pct_exec "git clone --depth=1 https://github.com/5etools-mirror-3/5etools-src.git /opt/5etools-src" &>/dev/null
msg_ok "Cloned 5eTools source"

# ---------------------------------------------------------------------------
# Install Node dependencies
# ---------------------------------------------------------------------------
msg_info "Installing Node.js dependencies (npm install)"
pct_exec "cd /opt/5etools-src && npm install --loglevel=error" &>/dev/null
msg_ok "Installed Node.js dependencies"

# ---------------------------------------------------------------------------
# Build service worker (enables client-side caching over LAN)
# ---------------------------------------------------------------------------
msg_info "Building service worker"
pct_exec "cd /opt/5etools-src && npm run build:sw:prod" &>/dev/null
msg_ok "Built service worker"

# ---------------------------------------------------------------------------
# Create optional image-download helper inside container
# ---------------------------------------------------------------------------
msg_info "Creating image helper script inside container"
pct_exec "cat > /opt/install-5etools-img.sh << 'IMGEOF'
#!/usr/bin/env bash
# Run this script from INSIDE the 5eTools container to download the
# full image repository (~5-7 GB).  Images include monster art,
# spell illustrations, and map assets.
#
#   pct exec <CTID> -- bash /opt/install-5etools-img.sh
#   # or from inside the container:
#   bash /opt/install-5etools-img.sh

echo 'Downloading 5eTools image repo — this can take 10–30+ minutes.'

if [[ -d /opt/5etools-src/img/.git ]]; then
  echo 'Images already present; pulling latest changes...'
  cd /opt/5etools-src/img && git pull
else
  git clone --depth=1 \
    https://github.com/5etools-mirror-3/5etools-img.git \
    /opt/5etools-src/img
fi

echo ''
echo 'Done!  Restart the service to apply:'
echo '  systemctl restart 5etools'
IMGEOF
chmod +x /opt/install-5etools-img.sh"
msg_ok "Created /opt/install-5etools-img.sh inside container"

# ---------------------------------------------------------------------------
# Create systemd service
# ---------------------------------------------------------------------------
msg_info "Creating systemd service"
pct_exec "cat > /etc/systemd/system/5etools.service << 'SVCEOF'
[Unit]
Description=5eTools local D&D reference server
Documentation=https://wiki.tercept.net/en/5eTools/InstallGuide
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/5etools-src
ExecStart=/usr/bin/npm run serve:dev
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=5etools

[Install]
WantedBy=multi-user.target
SVCEOF"

pct_exec "systemctl daemon-reload && systemctl enable --now 5etools" &>/dev/null
msg_ok "Created and started 5etools.service"

# ---------------------------------------------------------------------------
# Create /usr/bin/update helper (mirrors community-scripts convention)
# ---------------------------------------------------------------------------
msg_info "Creating update helper (/usr/bin/update)"
pct_exec "cat > /usr/bin/update << 'UPEOF'
#!/usr/bin/env bash
# Update 5eTools in-place using git pull.
# Called nightly by the 5etools-update systemd timer, or run manually:
#   pct exec <CTID> -- bash /usr/bin/update

set -euo pipefail
INSTALL_DIR=\"/opt/5etools-src\"
LOG_FILE=\"/var/log/5etools-update.log\"

log() { echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$*\" | tee -a \"\${LOG_FILE}\"; }

log \"--- 5eTools update started ---\"

log \"Stopping service...\"
systemctl stop 5etools

log \"Pulling latest 5eTools source...\"
cd \"\${INSTALL_DIR}\"
git pull >> \"\${LOG_FILE}\" 2>&1

if [[ -d \"\${INSTALL_DIR}/img/.git\" ]]; then
  log \"Pulling latest images...\"
  cd \"\${INSTALL_DIR}/img\" && git pull >> \"\${LOG_FILE}\" 2>&1
  cd \"\${INSTALL_DIR}\"
fi

log \"Updating Node.js dependencies...\"
npm install --loglevel=error >> \"\${LOG_FILE}\" 2>&1

log \"Rebuilding service worker...\"
npm run build:sw:prod >> \"\${LOG_FILE}\" 2>&1

log \"Restarting service...\"
systemctl start 5etools

log \"--- 5eTools update complete ---\"
UPEOF
chmod +x /usr/bin/update"
msg_ok "Created /usr/bin/update"

# ---------------------------------------------------------------------------
# Create systemd timer for nightly auto-update at 01:00
# ---------------------------------------------------------------------------
msg_info "Creating nightly auto-update timer (01:00 daily)"

# The service unit that runs the update script
pct_exec "cat > /etc/systemd/system/5etools-update.service << 'SVEOF'
[Unit]
Description=5eTools nightly update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/update
StandardOutput=journal
StandardError=journal
SyslogIdentifier=5etools-update
SVEOF"

# The timer unit that triggers it at 01:00 every day
pct_exec "cat > /etc/systemd/system/5etools-update.timer << 'TMEOF'
[Unit]
Description=Run 5eTools update nightly at 01:00
Requires=5etools-update.service

[Timer]
OnCalendar=*-*-* 01:00:00
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
TMEOF"

pct_exec "systemctl daemon-reload && systemctl enable --now 5etools-update.timer" &>/dev/null
msg_ok "Nightly auto-update timer enabled (fires at 01:00, ±5 min random delay)"

# ---------------------------------------------------------------------------
# Retrieve container IP
# ---------------------------------------------------------------------------
sleep 3
CT_IP=$(pct exec "${CT_ID}" -- hostname -I 2>/dev/null | awk '{print $1}' || echo "<container-ip>")

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e " ${GN}============================================================${CL}"
echo -e " ${CM} ${GN}5eTools installation completed successfully!${CL}"
echo -e " ${GN}============================================================${CL}"
echo ""
echo -e " ${YW}Container ID  :${CL} ${CT_ID}"
echo -e " ${YW}Container IP  :${CL} ${CT_IP}"
echo -e " ${YW}Root password :${CL} ${CT_PASSWORD}"
echo ""
echo -e " ${YW}Access 5eTools in your browser:${CL}"
echo -e "   ${GN}http://${CT_IP}:${SERVE_PORT}/index.html${CL}"
echo ""
echo -e " ${YW}Optional — download images (~5-7 GB) for offline art:${CL}"
echo -e "   pct exec ${CT_ID} -- bash /opt/install-5etools-img.sh"
echo ""
echo -e " ${YW}Auto-update     :${CL} nightly at 01:00 (systemd timer)"
echo -e " ${YW}Update log      :${CL} /var/log/5etools-update.log (inside container)"
echo ""
echo -e " ${YW}Manual update:${CL}"
echo -e "   pct exec ${CT_ID} -- bash /usr/bin/update"
echo ""
echo -e " ${YW}Check timer status:${CL}"
echo -e "   pct exec ${CT_ID} -- systemctl status 5etools-update.timer"
echo ""
echo -e " ${YW}View update log:${CL}"
echo -e "   pct exec ${CT_ID} -- tail -50 /var/log/5etools-update.log"
echo ""
echo -e " ${YW}Enter the container shell:${CL}"
echo -e "   pct enter ${CT_ID}"
echo ""
