<div align="center">

Proxmox 5eTools Installer

Deploy a self-hosted 5eTools server in a Proxmox LXC container



A guided, automated installer that creates a Debian LXC container, installs 5eTools, optionally downloads image assets, configures automatic updates, and starts the web server.

</div>

Overview

This project provides a standalone installer for running a local 5eTools instance on Proxmox VE.

The user launches the script once, selects the desired installation options, and the installer completes the remaining work automatically.

The installer automatically

Selects the next available Proxmox container ID

Creates an unprivileged Debian 12 or Debian 13 LXC container

Installs Node.js 24 and required dependencies

Clones and prepares the 5eTools source

Optionally downloads the complete image repository

Creates and enables the 5eTools systemd service

Optionally enables nightly automatic updates

Starts 5eTools when installation finishes

Removes package caches and temporary installation files

Rolls back an incomplete container if installation fails

Verifies that the web service is running

Displays the final browser URL and generated root password

[!IMPORTANT]Run the installer from the Proxmox host shell as root.Do not run it from inside another LXC container or virtual machine.

[!NOTE]Current 5eTools releases require Node.js 24 or newer. The installer configures NodeSource 24.x and verifies the installed major version before continuing.

Quick Start

Run the installer directly from the Proxmox host shell with one command:

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)"

The command downloads the latest installer directly into Bash, displays the installation options, completes the deployment, and starts 5eTools.

No separate download, chmod, or second execution command is required.

[!IMPORTANT]Run this command from the Proxmox host shell as root.

Installation Options

At startup, the installer presents all deployment choices before creating the container.

The user can select:

Debian version: Debian 12 Bookworm or Debian 13 Trixie

Image repository: optionally download the full 5eTools image collection

Automatic updates: optionally enable the nightly systemd update timer

Web port: choose the TCP port used by the 5eTools web server

After these selections are made, the installation continues automatically and 5eTools starts when setup finishes.

The installer dynamically selects the newest available Proxmox LXC template matching the chosen Debian release. No hardcoded Debian template filename is required.

Unattended Installation

The installer supports command-line options for fully unattended deployment.

Install with Default Settings

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- --defaults

Install Debian 13

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- --defaults --debian 13

Install with Images

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- --defaults --images

Install with a Custom Port

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- --defaults --port 8080

Combine Options

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- \
  --defaults \
  --debian 13 \
  --images \
  --port 8080

Specify a Container ID

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- \
  120 \
  --defaults \
  --debian 12

Supported unattended options include:

Option

Purpose

--defaults

Skip the interactive installer menus

--debian 12

Use Debian 12 Bookworm

--debian 13

Use Debian 13 Trixie

--images

Download the full 5eTools image repository

--port PORT

Set the web server port

Container ID argument

Use a specific Proxmox container ID

[!WARNING]A manually selected container ID must not already exist.

Default Configuration

Setting

Default value

Hostname

5etools

Debian version

Debian 12 Bookworm

Container type

Unprivileged LXC

Container ID

Next available ID

Storage

local-lvm

Template storage

local

Template version

Newest available matching release

Disk size

20 GB

Memory

2048 MB

CPU cores

2

Network bridge

vmbr0

IP configuration

DHCP

Web port

5050

Service startup

Automatic

Image repository

User-selectable

Nightly updates

User-selectable

The defaults can be changed near the beginning of install.sh.

Requirements

Before running the installer, confirm that the Proxmox host has:

A working Proxmox VE installation

Root shell access

Internet connectivity

A storage target named local-lvm

Template storage named local

A Linux bridge named vmbr0

DHCP available on the selected network

A Debian 12 or Debian 13 LXC template available through pveam

At least 20 GB of free storage

Additional free space when downloading image assets

Check available storage:

pvesm status

Check available interfaces and bridges:

ip link show

If the storage or bridge names differ, update the configuration variables in the installer before running it.

Installation Process

After the user selects the installation options, the script performs these steps automatically:

Checks that it is running as root on a Proxmox VE host

Selects or accepts a container ID

Locates or downloads the newest template for the selected Debian release

Creates an unprivileged LXC container

Starts the container and waits for networking

Updates Debian packages

Installs Git, curl, certificates, GnuPG, and Node.js 24

Clones the 5eTools source into /opt/5etools-src

Installs the Node.js dependencies

Builds the production service worker

Downloads image assets when selected

Creates the 5etools.service systemd unit

Creates update tools and the update timer when selected

Enables and starts the 5eTools service

Removes APT, npm, and temporary installation caches

Starts and verifies the 5eTools web server

Displays the completed installation details

No separate image-install command or service-start command is required when those options are selected during installation.

Accessing 5eTools

When installation finishes, the script displays:

Container ID

Container IP address

Generated root password

Browser URL

Image installation status

Automatic update status

Open the displayed address:

http://CONTAINER-IP:5050/index.html

Example:

http://192.168.1.50:5050/index.html

The service starts automatically when the installer completes and whenever the container boots.

The selected port is written into the systemd service and used by the post-install health check.

Image Assets

The image repository contains monster artwork, maps, spell illustrations, and other assets.

Select the image option when the installer starts, or use:

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- --defaults --images

When enabled, the images are downloaded during installation. The installer then starts 5eTools with the assets already available.

[!CAUTION]The image repository can require approximately 5–7 GB of additional disk space and can significantly increase installation time.

Automatic Updates

When automatic updates are enabled, the installer creates a systemd timer that runs nightly at approximately 01:00, with a randomized delay of up to five minutes.

Each update:

Stops the 5eTools service

Pulls the latest source changes

Updates the image repository when installed

Runs npm install

Rebuilds the service worker

Restarts the service

Run an Update Manually

pct exec CONTAINER_ID -- bash /usr/bin/update

View the Update Log

pct exec CONTAINER_ID -- cat /var/log/5etools-update.log

Check the Update Timer

pct exec CONTAINER_ID -- systemctl status 5etools-update.timer

View Upcoming Timer Runs

pct exec CONTAINER_ID -- systemctl list-timers 5etools-update.timer

Installation Cleanup and Failure Rollback

The installer cleans up after itself before completing.

Successful installation

The installer automatically:

Removes unused Debian packages when safe to do so

Clears downloaded APT package caches

Removes stale APT package lists

Clears the npm download cache

Removes temporary files from /tmp and /var/tmp inside the container

Removes installer-specific temporary files from the Proxmox host

The installed 5eTools source, optional images, systemd services, updater, and logs are preserved.

Failed installation

If an error occurs after the new LXC container is created, the installer automatically:

Stops the incomplete container when necessary

Destroys the incomplete container

Purges its Proxmox configuration

Removes installer-specific temporary files

[!IMPORTANT]Rollback applies only to the new container created by the current installer run. The installer refuses to use an existing container ID and will not remove an existing container.

Service Management

The installer enables and starts the service automatically.

Check Service Status

pct exec CONTAINER_ID -- systemctl status 5etools

Restart the Service

pct exec CONTAINER_ID -- systemctl restart 5etools

View Recent Logs

pct exec CONTAINER_ID -- journalctl -u 5etools -n 100 --no-pager

Follow Logs Live

pct exec CONTAINER_ID -- journalctl -u 5etools -f

Customization

The interactive installer exposes the most common settings directly:

Debian 12 or Debian 13

Image installation

Automatic updates

Web port

Additional defaults can be edited near the top of install.sh:

CT_HOSTNAME="5etools"
CT_STORAGE="local-lvm"
CT_DISK="20"
CT_RAM="2048"
CT_CPU="2"
CT_BRIDGE="vmbr0"
CT_OS_STORAGE="local"
DEBIAN_VERSION="12"
SERVE_PORT="5050"

The Debian template filename is not hardcoded. The installer queries Proxmox and selects the newest matching amd64 template for Debian 12 or Debian 13.

[!TIP]Use pveam available --section system to confirm which Debian templates are currently available on your Proxmox host.

Troubleshooting

<details>
<summary><strong><code>pct not found</code></strong></summary>

The installer is not running directly on a Proxmox VE host.

Run it from the Proxmox host shell as root.

</details>

<details>
<summary><strong>The installer exits because it is not root</strong></summary>

Open the Proxmox root shell or switch to root:

su -

Then run:

bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)"

</details>

<details>
<summary><strong>Configured storage does not exist</strong></summary>

List available storage targets:

pvesm status

Update these installer variables:

CT_STORAGE="your-container-storage"
CT_OS_STORAGE="your-template-storage"

</details>

<details>
<summary><strong>Configured network bridge does not exist</strong></summary>

List available interfaces:

ip link show

Update the bridge variable:

CT_BRIDGE="your-bridge-name"

</details>

<details>
<summary><strong>No matching Debian template is found</strong></summary>

Refresh the Proxmox appliance catalog:

pveam update

List the available Debian templates:

pveam available --section system | grep debian

Confirm that the selected release is available:

Debian 12 uses --debian 12

Debian 13 uses --debian 13

Also verify that CT_OS_STORAGE points to storage that supports LXC templates.

</details>

<details>
<summary><strong>The container has no IP address</strong></summary>

Inspect the container networking:

pct config CONTAINER_ID
pct exec CONTAINER_ID -- ip address
pct exec CONTAINER_ID -- ip route

Confirm that DHCP is available on the selected bridge.

</details>

<details>
<summary><strong>The web page does not load</strong></summary>

Confirm that the container is running:

pct status CONTAINER_ID

Check the service:

pct exec CONTAINER_ID -- systemctl status 5etools

Check listening ports:

pct exec CONTAINER_ID -- ss -lntp

View the service logs:

pct exec CONTAINER_ID -- journalctl -u 5etools -n 100 --no-pager

Also verify that TCP port 5050 is allowed through any Proxmox, container, host, router, or client firewall.

</details>

<details>
<summary><strong>The image download fails</strong></summary>

Check available disk space:

pct exec CONTAINER_ID -- df -h

Confirm that the container can reach GitHub:

pct exec CONTAINER_ID -- curl -I https://github.com

Review the installer output for the failing Git command.

</details>

File Locations

Purpose

Path inside the container

5eTools source

/opt/5etools-src

Image repository

/opt/5etools-src/img

Image helper

/opt/install-5etools-img.sh

Manual updater

/usr/bin/update

Main service

/etc/systemd/system/5etools.service

Update service

/etc/systemd/system/5etools-update.service

Update timer

/etc/systemd/system/5etools-update.timer

Update log

/var/log/5etools-update.log

Uninstalling

[!CAUTION]Destroying the container permanently removes 5eTools and all data stored inside the container.

Stop and destroy the container:

pct stop CONTAINER_ID
pct destroy CONTAINER_ID

Verify the container ID before running these commands.

Upstream Projects

This installer deploys content from:

5etools-mirror-3/5etools-src

5etools-mirror-3/5etools-img

This repository is an independent deployment helper and is not affiliated with Wizards of the Coast or the upstream 5eTools maintainers.

License

The installer script is provided under the MIT License.

The upstream 5eTools source code, data, images, trademarks, and game content may be governed by separate licenses or terms. Review the relevant upstream repositories before redistributing content.
