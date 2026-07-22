#!/usr/bin/env bash
# =============================================================================
# 5eTools — Standalone Proxmox LXC Installer
# =============================================================================
# Run from the Proxmox host shell:
#
#   bash 5etools-standalone.sh
#
# The installer shows one options screen, then completes the deployment without
# further prompts. It creates an LXC container, installs 5eTools, optionally
# downloads images, configures updates, and starts the web service.
#
# Unattended examples:
#   bash 5etools-standalone.sh --defaults
#   bash 5etools-standalone.sh --images --auto-updates
#   bash 5etools-standalone.sh --no-images --no-auto-updates
# =============================================================================

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Colors and messages
# ---------------------------------------------------------------------------
YW=$'\033[33m'
GN=$'\033[1;92m'
RD=$'\033[01;31m'
CY=$'\033[36m'
CL=$'\033[0m'
BFR=$'\r\033[K'
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

msg_info()  { printf "   ${YW}%s...${CL}" "$1"; }
msg_ok()    { printf "%s %b ${GN}%s${CL}\n" "${BFR}" "${CM}" "$1"; }
msg_warn()  { printf " ${YW}!${CL} %s\n" "$1"; }
msg_error() { printf "%s %b ${RD}%s${CL}\n" "${BFR}" "${CROSS}" "$1" >&2; }

CURRENT_STEP="Starting installer"
on_error() {
  local exit_code=$?
  echo
  msg_error "Installation failed while: ${CURRENT_STEP}"
  echo "   Exit code: ${exit_code}"
  if [[ -n "${CT_ID:-}" ]] && command -v pct &>/dev/null && pct status "${CT_ID}" &>/dev/null; then
    echo "   Container ${CT_ID} was left in place for troubleshooting."
  fi
  exit "${exit_code}"
}
trap on_error ERR

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
CT_ID=""
CT_HOSTNAME="5etools"
CT_PASSWORD=""
CT_STORAGE="local-lvm"
CT_DISK="20"
CT_RAM="2048"
CT_CPU="2"
CT_BRIDGE="vmbr0"
CT_OS_STORAGE="local"
SERVE_PORT="5050"

INSTALL_IMAGES="no"
ENABLE_AUTO_UPDATES="yes"
UNATTENDED="no"
SHOW_MENU="yes"

# ---------------------------------------------------------------------------
# CLI arguments
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage:
  bash 5etools-standalone.sh [container-id] [options]

Options:
  --defaults             Use defaults with no menu
  --images               Download the optional image repository
  --no-images            Do not download the image repository
  --auto-updates         Enable nightly automatic updates
  --no-auto-updates      Disable nightly automatic updates
  --ctid ID              Use a specific container ID
  --hostname NAME        Set the container hostname
  --storage NAME         Set container storage
  --template-storage NAME
                         Set template storage
  --bridge NAME          Set the network bridge
  --disk GB              Set disk size
  --ram MB               Set memory
  --cores COUNT          Set CPU core count
  --port PORT            Set the 5eTools web port
  -h, --help             Show this help

Examples:
  bash 5etools-standalone.sh
  bash 5etools-standalone.sh 120 --images
  bash 5etools-standalone.sh --defaults
EOF
}

while (($#)); do
  case "$1" in
    --defaults)
      UNATTENDED="yes"
      SHOW_MENU="no"
      shift
      ;;
    --images)
      INSTALL_IMAGES="yes"
      shift
      ;;
    --no-images)
      INSTALL_IMAGES="no"
      shift
      ;;
    --auto-updates)
      ENABLE_AUTO_UPDATES="yes"
      shift
      ;;
    --no-auto-updates)
      ENABLE_AUTO_UPDATES="no"
      shift
      ;;
    --ctid)
      CT_ID="${2:?Missing value for --ctid}"
      shift 2
      ;;
    --hostname)
      CT_HOSTNAME="${2:?Missing value for --hostname}"
      shift 2
      ;;
    --storage)
      CT_STORAGE="${2:?Missing value for --storage}"
      shift 2
      ;;
    --template-storage)
      CT_OS_STORAGE="${2:?Missing value for --template-storage}"
      shift 2
      ;;
    --bridge)
      CT_BRIDGE="${2:?Missing value for --bridge}"
      shift 2
      ;;
    --disk)
      CT_DISK="${2:?Missing value for --disk}"
      shift 2
      ;;
    --ram)
      CT_RAM="${2:?Missing value for --ram}"
      shift 2
      ;;
    --cores)
      CT_CPU="${2:?Missing value for --cores}"
      shift 2
      ;;
    --port)
      SERVE_PORT="${2:?Missing value for --port}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    ''|*[!0-9]*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "${CT_ID}" ]]; then
        echo "Container ID specified more than once." >&2
        exit 2
      fi
      CT_ID="$1"
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
CURRENT_STEP="checking the Proxmox host"

if [[ ${EUID} -ne 0 ]]; then
  msg_error "This script must be run as root on the Proxmox host"
  exit 1
fi

if ! command -v pct &>/dev/null || ! command -v pvesh &>/dev/null; then
  msg_error "Proxmox commands were not found. Run this on a Proxmox VE host."
  exit 1
fi

if [[ -z "${CT_ID}" ]]; then
  CT_ID="$(pvesh get /cluster/nextid)"
fi

if pct status "${CT_ID}" &>/dev/null; then
  msg_error "Container ID ${CT_ID} already exists"
  exit 1
fi

if ! pvesm status -storage "${CT_STORAGE}" &>/dev/null; then
  msg_error "Container storage '${CT_STORAGE}' does not exist"
  echo "Available storage:"
  pvesm status || true
  exit 1
fi

if ! pvesm status -storage "${CT_OS_STORAGE}" &>/dev/null; then
  msg_error "Template storage '${CT_OS_STORAGE}' does not exist"
  echo "Available storage:"
  pvesm status || true
  exit 1
fi

if ! ip link show "${CT_BRIDGE}" &>/dev/null; then
  msg_error "Network bridge '${CT_BRIDGE}' does not exist"
  exit 1
fi

CT_PASSWORD="$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)"

# ---------------------------------------------------------------------------
# Header and option selection
# ---------------------------------------------------------------------------
clear 2>/dev/null || true
cat <<EOF
${CY}
  ____  ___  _____           _
 | ___|/ _ \|_   _|__   ___ | |___
 |___ \ (_) | | |/ _ \ / _ \| / __|
  ___) \__, | | | (_) | (_) | \__ \\
 |____/  /_/  |_|\___/ \___/|_|___/
${CL}
  Local 5eTools — Proxmox LXC Installer
EOF

if [[ "${SHOW_MENU}" == "yes" ]]; then
  if command -v whiptail &>/dev/null && [[ -t 0 ]]; then
    set +e
    CHOICES=$(whiptail \
      --title "5eTools Installation Options" \
      --checklist \
      "Select optional components. Press Space to toggle, then Enter to install." \
      16 72 4 \
      "images" "Download full image repository (adds about 5–7 GB)" OFF \
      "updates" "Enable nightly automatic updates" ON \
      3>&1 1>&2 2>&3)
    MENU_STATUS=$?
    set -e

    if [[ ${MENU_STATUS} -ne 0 ]]; then
      echo "Installation cancelled."
      exit 0
    fi

    INSTALL_IMAGES="no"
    ENABLE_AUTO_UPDATES="no"
    [[ "${CHOICES}" == *'"images"'* ]] && INSTALL_IMAGES="yes"
    [[ "${CHOICES}" == *'"updates"'* ]] && ENABLE_AUTO_UPDATES="yes"
  elif [[ -t 0 ]]; then
    echo
    echo "Optional components:"
    echo "  1) Standard install"
    echo "  2) Install with full image repository"
    echo "  3) Standard install without automatic updates"
    echo "  4) Install images without automatic updates"
    echo
    read -r -p "Select [1-4, default 1]: " MENU_CHOICE
    case "${MENU_CHOICE:-1}" in
      1) INSTALL_IMAGES="no";  ENABLE_AUTO_UPDATES="yes" ;;
      2) INSTALL_IMAGES="yes"; ENABLE_AUTO_UPDATES="yes" ;;
      3) INSTALL_IMAGES="no";  ENABLE_AUTO_UPDATES="no" ;;
      4) INSTALL_IMAGES="yes"; ENABLE_AUTO_UPDATES="no" ;;
      *) msg_error "Invalid selection"; exit 2 ;;
    esac
  fi
fi

echo
echo -e " ${YW}Container ID     :${CL} ${CT_ID}"
echo -e " ${YW}Hostname         :${CL} ${CT_HOSTNAME}"
echo -e " ${YW}RAM              :${CL} ${CT_RAM} MB"
echo -e " ${YW}CPU              :${CL} ${CT_CPU} cores"
echo -e " ${YW}Disk             :${CL} ${CT_DISK} GB"
echo -e " ${YW}Bridge           :${CL} ${CT_BRIDGE}"
echo -e " ${YW}Web port         :${CL} ${SERVE_PORT}"
echo -e " ${YW}Install images   :${CL} ${INSTALL_IMAGES}"
echo -e " ${YW}Automatic updates:${CL} ${ENABLE_AUTO_UPDATES}"
echo
echo "Installation is starting automatically."
echo

# ---------------------------------------------------------------------------
# Locate or download the newest Debian 12 template
# ---------------------------------------------------------------------------
CURRENT_STEP="locating a Debian 12 template"
msg_info "Checking for a Debian 12 template"

TEMPLATE_PATH="$(
  pveam list "${CT_OS_STORAGE}" 2>/dev/null |
    awk '/debian-12-standard_.*_amd64\.tar\.(zst|gz)$/ {print $1}' |
    sort -V |
    tail -n1
)"

if [[ -z "${TEMPLATE_PATH}" ]]; then
  msg_info "Downloading the latest Debian 12 template"
  pveam update &>/dev/null

  CT_OS_TEMPLATE="$(
    pveam available --section system 2>/dev/null |
      awk '/debian-12-standard_.*_amd64\.tar\.(zst|gz)$/ {print $2}' |
      sort -V |
      tail -n1
  )"

  if [[ -z "${CT_OS_TEMPLATE}" ]]; then
    msg_error "No Debian 12 template was found in the Proxmox appliance list"
    exit 1
  fi

  pveam download "${CT_OS_STORAGE}" "${CT_OS_TEMPLATE}" &>/dev/null
  TEMPLATE_PATH="${CT_OS_STORAGE}:vztmpl/${CT_OS_TEMPLATE}"
  msg_ok "Downloaded ${CT_OS_TEMPLATE}"
else
  msg_ok "Using ${TEMPLATE_PATH}"
fi

# ---------------------------------------------------------------------------
# Create and start the LXC container
# ---------------------------------------------------------------------------
CURRENT_STEP="creating LXC container ${CT_ID}"
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
  --onboot 1 \
  --start 0 \
  &>/dev/null
msg_ok "Created LXC container ${CT_ID}"

CURRENT_STEP="starting container ${CT_ID}"
msg_info "Starting container"
pct start "${CT_ID}" &>/dev/null

for _ in {1..30}; do
  if pct exec "${CT_ID}" -- true &>/dev/null; then
    break
  fi
  sleep 1
done

if ! pct exec "${CT_ID}" -- true &>/dev/null; then
  msg_error "Container did not become ready"
  exit 1
fi
msg_ok "Container started"

pct_exec() {
  pct exec "${CT_ID}" -- bash -lc "$1"
}

# ---------------------------------------------------------------------------
# Install operating-system dependencies
# ---------------------------------------------------------------------------
CURRENT_STEP="updating the container operating system"
msg_info "Updating container OS"
pct_exec "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get upgrade -y -qq" &>/dev/null
msg_ok "Updated container OS"

CURRENT_STEP="installing base dependencies"
msg_info "Installing base dependencies"
pct_exec "export DEBIAN_FRONTEND=noninteractive; apt-get install -y -qq git curl ca-certificates gnupg openssl" &>/dev/null
msg_ok "Installed base dependencies"

CURRENT_STEP="installing Node.js 22"
msg_info "Installing Node.js 22"
pct_exec '
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key |
    gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
' &>/dev/null
NODE_VER="$(pct_exec "node -v")"
msg_ok "Installed Node.js ${NODE_VER}"

# ---------------------------------------------------------------------------
# Install 5eTools
# ---------------------------------------------------------------------------
CURRENT_STEP="cloning the 5eTools source"
msg_info "Cloning 5eTools source"
pct_exec "git clone --depth=1 https://github.com/5etools-mirror-3/5etools-src.git /opt/5etools-src" &>/dev/null
msg_ok "Cloned 5eTools source"

CURRENT_STEP="installing Node.js dependencies"
msg_info "Installing Node.js dependencies"
pct_exec "cd /opt/5etools-src && npm install --loglevel=error" &>/dev/null
msg_ok "Installed Node.js dependencies"

CURRENT_STEP="building the service worker"
msg_info "Building service worker"
pct_exec "cd /opt/5etools-src && npm run build:sw:prod" &>/dev/null
msg_ok "Built service worker"

# ---------------------------------------------------------------------------
# Optional image repository
# ---------------------------------------------------------------------------
CURRENT_STEP="creating the image installer"
msg_info "Creating image helper"
pct exec "${CT_ID}" -- bash -s <<'IMGHELPER'
cat > /opt/install-5etools-img.sh <<'IMGEOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -d /opt/5etools-src/img/.git ]]; then
  echo "Updating the 5eTools image repository..."
  git -C /opt/5etools-src/img pull --ff-only
else
  echo "Downloading the 5eTools image repository..."
  git clone --depth=1 \
    https://github.com/5etools-mirror-3/5etools-img.git \
    /opt/5etools-src/img
fi

systemctl restart 5etools 2>/dev/null || true
echo "Image installation complete."
IMGEOF
chmod +x /opt/install-5etools-img.sh
IMGHELPER
msg_ok "Created image helper"

if [[ "${INSTALL_IMAGES}" == "yes" ]]; then
  CURRENT_STEP="downloading the image repository"
  msg_info "Downloading image repository"
  pct_exec "/opt/install-5etools-img.sh" &>/dev/null
  msg_ok "Downloaded image repository"
fi

# ---------------------------------------------------------------------------
# Main systemd service
# ---------------------------------------------------------------------------
CURRENT_STEP="creating the 5eTools service"
msg_info "Creating 5eTools service"
pct exec "${CT_ID}" -- bash -s -- "${SERVE_PORT}" <<'SERVICE'
SERVE_PORT="$1"
cat > /etc/systemd/system/5etools.service <<EOF
[Unit]
Description=5eTools local D&D reference server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/5etools-src
Environment=NODE_ENV=production
ExecStart=/usr/bin/npm run serve:dev -- --host 0.0.0.0 --port ${SERVE_PORT}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=5etools

[Install]
WantedBy=multi-user.target
EOF
SERVICE
msg_ok "Created 5eTools service"

# ---------------------------------------------------------------------------
# Update helper and optional timer
# ---------------------------------------------------------------------------
CURRENT_STEP="creating the update helper"
msg_info "Creating update helper"
pct exec "${CT_ID}" -- bash -s <<'UPDATER'
cat > /usr/local/sbin/update-5etools <<'UPEOF'
#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="/opt/5etools-src"
LOG_FILE="/var/log/5etools-update.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

restart_service() {
  systemctl start 5etools || true
}
trap restart_service EXIT

log "--- 5eTools update started ---"
systemctl stop 5etools

log "Pulling latest 5eTools source..."
git -C "${INSTALL_DIR}" pull --ff-only >>"${LOG_FILE}" 2>&1

if [[ -d "${INSTALL_DIR}/img/.git" ]]; then
  log "Pulling latest images..."
  git -C "${INSTALL_DIR}/img" pull --ff-only >>"${LOG_FILE}" 2>&1
fi

log "Updating Node.js dependencies..."
cd "${INSTALL_DIR}"
npm install --loglevel=error >>"${LOG_FILE}" 2>&1

log "Rebuilding service worker..."
npm run build:sw:prod >>"${LOG_FILE}" 2>&1

log "Restarting service..."
systemctl start 5etools
trap - EXIT
log "--- 5eTools update complete ---"
UPEOF

chmod +x /usr/local/sbin/update-5etools
ln -sf /usr/local/sbin/update-5etools /usr/bin/update
UPDATER
msg_ok "Created update helper"

if [[ "${ENABLE_AUTO_UPDATES}" == "yes" ]]; then
  CURRENT_STEP="configuring automatic updates"
  msg_info "Enabling nightly updates"
  pct exec "${CT_ID}" -- bash -s <<'TIMER'
cat > /etc/systemd/system/5etools-update.service <<'EOF'
[Unit]
Description=Update 5eTools
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/update-5etools
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/5etools-update.timer <<'EOF'
[Unit]
Description=Run the 5eTools updater nightly

[Timer]
OnCalendar=*-*-* 01:00:00
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF
TIMER
  pct_exec "systemctl daemon-reload; systemctl enable --now 5etools-update.timer" &>/dev/null
  msg_ok "Enabled nightly updates"
else
  msg_ok "Automatic updates disabled"
fi

# ---------------------------------------------------------------------------
# Start and verify the application
# ---------------------------------------------------------------------------
CURRENT_STEP="starting the 5eTools application"
msg_info "Starting 5eTools"
pct_exec "systemctl daemon-reload; systemctl enable --now 5etools.service" &>/dev/null

for _ in {1..60}; do
  if pct_exec "curl -fsS http://127.0.0.1:${SERVE_PORT}/index.html >/dev/null" &>/dev/null; then
    break
  fi
  sleep 2
done

if ! pct_exec "curl -fsS http://127.0.0.1:${SERVE_PORT}/index.html >/dev/null" &>/dev/null; then
  echo
  pct_exec "systemctl status 5etools --no-pager -l" || true
  pct_exec "journalctl -u 5etools -n 50 --no-pager" || true
  msg_error "5eTools did not respond on port ${SERVE_PORT}"
  exit 1
fi
msg_ok "5eTools is running"

# ---------------------------------------------------------------------------
# Retrieve IP and show completion details
# ---------------------------------------------------------------------------
CURRENT_STEP="retrieving the container IP address"
CT_IP=""
for _ in {1..30}; do
  CT_IP="$(pct exec "${CT_ID}" -- hostname -I 2>/dev/null | awk '{print $1}')"
  [[ -n "${CT_IP}" ]] && break
  sleep 1
done
CT_IP="${CT_IP:-CONTAINER-IP}"

trap - ERR

echo
echo -e " ${GN}============================================================${CL}"
echo -e " ${CM} ${GN}5eTools installation completed successfully!${CL}"
echo -e " ${GN}============================================================${CL}"
echo
echo -e " ${YW}Container ID     :${CL} ${CT_ID}"
echo -e " ${YW}Container IP     :${CL} ${CT_IP}"
echo -e " ${YW}Root password    :${CL} ${CT_PASSWORD}"
echo -e " ${YW}Images installed :${CL} ${INSTALL_IMAGES}"
echo -e " ${YW}Automatic updates:${CL} ${ENABLE_AUTO_UPDATES}"
echo
echo -e " ${YW}Open 5eTools:${CL}"
echo -e "   ${GN}http://${CT_IP}:${SERVE_PORT}/index.html${CL}"
echo
echo "The container and 5eTools service are running. No additional setup is required."
echo
