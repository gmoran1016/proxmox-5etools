Proxmox 5eTools Installer

A standalone Bash installer for deploying a local 5eTools instance inside an unprivileged Proxmox VE LXC container.

The installer creates and configures the container, installs Node.js, clones the 5eTools source, creates a systemd service, and enables automatic nightly updates.

Features

Creates an unprivileged Debian 12 LXC container

Automatically selects the next available container ID

Installs Node.js 22, Git, curl, and required dependencies

Clones the 5eTools source repository

Builds the production service worker

Runs 5eTools as a systemd service

Serves the site on TCP port 5050

Creates an optional helper for downloading image assets

Installs a manual update command

Enables nightly automatic updates at approximately 1:00 AM

Default Container Configuration

Setting

Default

Hostname

5etools

Operating system

Debian 12

Storage

local-lvm

Disk

20 GB

Memory

2048 MB

CPU cores

2

Network bridge

vmbr0

Addressing

DHCP

Web port

5050

Container type

Unprivileged LXC

These defaults can be changed near the beginning of 5etools-standalone.sh before running it.

Requirements

A working Proxmox VE host

Root shell access on the Proxmox host

Internet access from both the host and the new container

A storage target named local-lvm

Template storage named local

A network bridge named vmbr0

DHCP available on the selected network

At least 20 GB of free storage

If your Proxmox storage or bridge names differ, edit the configuration variables in the installer first.

Installation

Run the following commands from the Proxmox host shell, not from inside an existing container.

wget -O 5etools-standalone.sh   https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/5etools-standalone.sh

chmod +x 5etools-standalone.sh
bash 5etools-standalone.sh

The installer displays the proposed container settings and asks for confirmation before creating anything.

Specify a Container ID

By default, the installer requests the next available Proxmox container ID. To use a specific ID, pass it as the first argument:

bash 5etools-standalone.sh 120

The selected ID must not already be in use.

Accessing 5eTools

After installation, the script prints the container ID, IP address, generated root password, and browser URL.

Open:

http://CONTAINER-IP:5050/index.html

Example:

http://192.168.1.50:5050/index.html

Optional Image Repository

The main installation does not download the full 5eTools image repository. To add monster art, maps, spell illustrations, and other image assets, run this command on the Proxmox host:

pct exec CONTAINER_ID -- bash /opt/install-5etools-img.sh

Then restart the service:

pct exec CONTAINER_ID -- systemctl restart 5etools

The image repository can require approximately 5–7 GB of additional storage.

Updating

Automatic Updates

The installer creates a systemd timer that runs every night at approximately 1:00 AM, with a randomized delay of up to five minutes.

The update process:

Stops the 5eTools service.

Pulls the latest source changes.

Updates the image repository when installed.

Runs npm install.

Rebuilds the service worker.

Restarts the 5eTools service.

Manual Update

Run the generated update helper from the Proxmox host:

pct exec CONTAINER_ID -- bash /usr/bin/update

View the Update Log

pct exec CONTAINER_ID -- cat /var/log/5etools-update.log

Check the Update Timer

pct exec CONTAINER_ID -- systemctl status 5etools-update.timer

List upcoming timer executions:

pct exec CONTAINER_ID -- systemctl list-timers 5etools-update.timer

Service Management

Check the application service:

pct exec CONTAINER_ID -- systemctl status 5etools

Restart it:

pct exec CONTAINER_ID -- systemctl restart 5etools

View recent logs:

pct exec CONTAINER_ID -- journalctl -u 5etools -n 100 --no-pager

Follow logs in real time:

pct exec CONTAINER_ID -- journalctl -u 5etools -f

Customization

Edit these variables near the top of 5etools-standalone.sh before installation:

CT_HOSTNAME="5etools"
CT_STORAGE="local-lvm"
CT_DISK="20"
CT_RAM="2048"
CT_CPU="2"
CT_BRIDGE="vmbr0"
CT_OS_STORAGE="local"
SERVE_PORT="5050"

The script currently expects the Debian template filename configured in CT_OS_TEMPLATE. If Proxmox provides a newer Debian 12 template under a different filename, update that variable before running the installer.

Troubleshooting

pct not found

The installer must run directly on a Proxmox VE host as root.

Storage Does Not Exist

Check the storage names configured on the host:

pvesm status

Then update CT_STORAGE and CT_OS_STORAGE in the script.

Network Bridge Does Not Exist

Check available bridges:

ip link show

Update CT_BRIDGE if your host does not use vmbr0.

Container Has No IP Address

Check the container network configuration and DHCP status:

pct config CONTAINER_ID
pct exec CONTAINER_ID -- ip address
pct exec CONTAINER_ID -- ip route

Web Page Does Not Load

Confirm the container is running and the service is active:

pct status CONTAINER_ID
pct exec CONTAINER_ID -- systemctl status 5etools
pct exec CONTAINER_ID -- ss -lntp

Also verify that firewalls between your browser and the container allow TCP port 5050.

Uninstalling

Destroying the container permanently removes the 5eTools installation and its data.

pct stop CONTAINER_ID
pct destroy CONTAINER_ID

Use the correct container ID and confirm that the container contains nothing else you need before destroying it.

Upstream Projects

This installer deploys source and optional image assets from:

5etools-mirror-3/5etools-src

5etools-mirror-3/5etools-img

This repository is an independent deployment helper and is not affiliated with Wizards of the Coast or the upstream 5eTools maintainers.

License

The installer script is provided under the MIT License. Upstream 5eTools source code, data, images, trademarks, and game content may be governed by separate licenses or terms. Review the applicable upstream repositories and licenses before redistributing content.
