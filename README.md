<div align="center">

# Proxmox 5eTools Installer

### Deploy a self-hosted 5eTools server in a Proxmox LXC container

[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-VE-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Debian](https://img.shields.io/badge/Debian-12-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Node.js](https://img.shields.io/badge/Node.js-24-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#license)

A guided, automated installer that creates a Debian LXC container, installs 5eTools, optionally downloads image assets, configures automatic updates, and starts the web server.

</div>

---

## Overview

This project provides a standalone installer for running a local 5eTools instance on Proxmox VE.

The user launches the script once, selects the desired installation options, and the installer completes the remaining work automatically.

### The installer automatically

- Selects the next available Proxmox container ID
- Creates an unprivileged Debian 12 LXC container
- Installs Node.js 24 and required dependencies
- Clones and prepares the 5eTools source
- Optionally downloads the complete image repository
- Creates and enables the 5eTools systemd service
- Optionally enables nightly automatic updates
- Starts 5eTools when installation finishes
- Removes package caches and temporary installation files
- Rolls back an incomplete container if installation fails
- Verifies that the web service is running
- Displays the final browser URL and generated root password

> [!IMPORTANT]
> Run the installer from the **Proxmox host shell as root**.
> Do not run it from inside another LXC container or virtual machine.

> [!NOTE]
> Current 5eTools releases require **Node.js 24 or newer**. The installer configures NodeSource 24.x and verifies the installed major version before continuing.

---

## Quick Start

Run the installer directly from the Proxmox host shell with one command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install-5etools.sh)"
```

The command downloads the latest installer directly into Bash, displays the installation options, completes the deployment, and starts 5eTools.

No separate download, `chmod`, or second execution command is required.

> [!IMPORTANT]
> Run this command from the **Proxmox host shell as root**.

---

## Installation Options

During an interactive installation, the script prompts for the available optional features before creating the container.

Depending on the selected options, the installer can:

- Download the full 5eTools image repository
- Enable nightly automatic updates
- Use the default Proxmox container configuration
- Continue unattended after the initial selections

Once the options are selected, the installation runs automatically and 5eTools starts at the end.

---

## Unattended Installation

The installer also supports command-line options for fully unattended deployment.

### Install with Default Settings

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install-5etools.sh)" -- --defaults
```

This skips the interactive options and installs 5eTools using the standard defaults.

### Install with Images

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install-5etools.sh)" -- --defaults --images
```

This performs an unattended installation and downloads the complete image repository during setup.

### Specify a Container ID

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install-5etools.sh)" -- 120
```

The selected container ID must not already exist.

Options can be combined when supported:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install-5etools.sh)" -- 120 --defaults --images
```

> [!WARNING]
> Confirm that the selected container ID is unused before starting the installer.

---

## Default Configuration

| Setting | Default value |
|:--|:--|
| Hostname | `5etools` |
| Operating system | Debian 12 |
| Container type | Unprivileged LXC |
| Container ID | Next available ID |
| Storage | `local-lvm` |
| Template storage | `local` |
| Disk size | 20 GB |
| Memory | 2048 MB |
| CPU cores | 2 |
| Network bridge | `vmbr0` |
| IP configuration | DHCP |
| Web port | `5050` |
| Service startup | Automatic |
| Image repository | User-selectable |
| Nightly updates | User-selectable |

The defaults can be changed near the beginning of `install-5etools.sh`.

---

## Requirements

Before running the installer, confirm that the Proxmox host has:

- A working Proxmox VE installation
- Root shell access
- Internet connectivity
- A storage target named `local-lvm`
- Template storage named `local`
- A Linux bridge named `vmbr0`
- DHCP available on the selected network
- At least 20 GB of free storage
- Additional free space when downloading image assets

Check available storage:

```bash
pvesm status
```

Check available interfaces and bridges:

```bash
ip link show
```

If the storage or bridge names differ, update the configuration variables in the installer before running it.

---

## Installation Process

After the user selects the installation options, the script performs these steps automatically:

1. Checks that it is running as root on a Proxmox VE host
2. Selects or accepts a container ID
3. Locates or downloads the configured Debian 12 template
4. Creates an unprivileged LXC container
5. Starts the container and waits for networking
6. Updates Debian packages
7. Installs Git, curl, certificates, GnuPG, and Node.js 24
8. Clones the 5eTools source into `/opt/5etools-src`
9. Installs the Node.js dependencies
10. Builds the production service worker
11. Downloads image assets when selected
12. Creates the `5etools.service` systemd unit
13. Creates update tools and the update timer when selected
14. Enables and starts the 5eTools service
15. Removes APT, npm, and temporary installation caches
16. Starts and verifies the 5eTools web server
17. Displays the completed installation details

No separate image-install command or service-start command is required when those options are selected during installation.

---

## Accessing 5eTools

When installation finishes, the script displays:

- Container ID
- Container IP address
- Generated root password
- Browser URL
- Image installation status
- Automatic update status

Open the displayed address:

```text
http://CONTAINER-IP:5050/index.html
```

Example:

```text
http://192.168.1.50:5050/index.html
```

The service starts automatically when the installer completes and whenever the container boots.

---

## Image Assets

The image repository contains monster artwork, maps, spell illustrations, and other assets.

Select the image option when the installer starts, or use:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install-5etools.sh)" -- --defaults --images
```

When enabled, the images are downloaded during installation. The installer then starts 5eTools with the assets already available.

> [!CAUTION]
> The image repository can require approximately **5–7 GB** of additional disk space and can significantly increase installation time.

---

## Automatic Updates

When automatic updates are enabled, the installer creates a systemd timer that runs nightly at approximately `01:00`, with a randomized delay of up to five minutes.

Each update:

1. Stops the 5eTools service
2. Pulls the latest source changes
3. Updates the image repository when installed
4. Runs `npm install`
5. Rebuilds the service worker
6. Restarts the service

### Run an Update Manually

```bash
pct exec CONTAINER_ID -- bash /usr/bin/update
```

### View the Update Log

```bash
pct exec CONTAINER_ID -- cat /var/log/5etools-update.log
```

### Check the Update Timer

```bash
pct exec CONTAINER_ID -- systemctl status 5etools-update.timer
```

### View Upcoming Timer Runs

```bash
pct exec CONTAINER_ID -- systemctl list-timers 5etools-update.timer
```

---

## Installation Cleanup and Failure Rollback

The installer cleans up after itself before completing.

### Successful installation

The installer automatically:

- Removes unused Debian packages when safe to do so
- Clears downloaded APT package caches
- Removes stale APT package lists
- Clears the npm download cache
- Removes temporary files from `/tmp` and `/var/tmp` inside the container
- Removes installer-specific temporary files from the Proxmox host

The installed 5eTools source, optional images, systemd services, updater, and logs are preserved.

### Failed installation

If an error occurs after the new LXC container is created, the installer automatically:

1. Stops the incomplete container when necessary
2. Destroys the incomplete container
3. Purges its Proxmox configuration
4. Removes installer-specific temporary files

> [!IMPORTANT]
> Rollback applies only to the new container created by the current installer run. The installer refuses to use an existing container ID and will not remove an existing container.

---

## Service Management

The installer enables and starts the service automatically.

### Check Service Status

```bash
pct exec CONTAINER_ID -- systemctl status 5etools
```

### Restart the Service

```bash
pct exec CONTAINER_ID -- systemctl restart 5etools
```

### View Recent Logs

```bash
pct exec CONTAINER_ID -- journalctl -u 5etools -n 100 --no-pager
```

### Follow Logs Live

```bash
pct exec CONTAINER_ID -- journalctl -u 5etools -f
```

---

## Customization

Edit the default configuration near the top of `install-5etools.sh`:

```bash
CT_HOSTNAME="5etools"
CT_STORAGE="local-lvm"
CT_DISK="20"
CT_RAM="2048"
CT_CPU="2"
CT_BRIDGE="vmbr0"
CT_OS_STORAGE="local"
SERVE_PORT="5050"
```

The Debian template is controlled separately:

```bash
CT_OS_TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
```

> [!TIP]
> If the configured Debian template is no longer available, change `CT_OS_TEMPLATE` to a currently available Debian 12 template before running the installer.

---

## Troubleshooting

<details>
<summary><strong><code>pct not found</code></strong></summary>

The installer is not running directly on a Proxmox VE host.

Run it from the Proxmox host shell as root.

</details>

<details>
<summary><strong>The installer exits because it is not root</strong></summary>

Open the Proxmox root shell or switch to root:

```bash
su -
```

Then run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install-5etools.sh)"
```

</details>

<details>
<summary><strong>Configured storage does not exist</strong></summary>

List available storage targets:

```bash
pvesm status
```

Update these installer variables:

```bash
CT_STORAGE="your-container-storage"
CT_OS_STORAGE="your-template-storage"
```

</details>

<details>
<summary><strong>Configured network bridge does not exist</strong></summary>

List available interfaces:

```bash
ip link show
```

Update the bridge variable:

```bash
CT_BRIDGE="your-bridge-name"
```

</details>

<details>
<summary><strong>The container has no IP address</strong></summary>

Inspect the container networking:

```bash
pct config CONTAINER_ID
pct exec CONTAINER_ID -- ip address
pct exec CONTAINER_ID -- ip route
```

Confirm that DHCP is available on the selected bridge.

</details>

<details>
<summary><strong>The web page does not load</strong></summary>

Confirm that the container is running:

```bash
pct status CONTAINER_ID
```

Check the service:

```bash
pct exec CONTAINER_ID -- systemctl status 5etools
```

Check listening ports:

```bash
pct exec CONTAINER_ID -- ss -lntp
```

View the service logs:

```bash
pct exec CONTAINER_ID -- journalctl -u 5etools -n 100 --no-pager
```

Also verify that TCP port `5050` is allowed through any Proxmox, container, host, router, or client firewall.

</details>

<details>
<summary><strong>The image download fails</strong></summary>

Check available disk space:

```bash
pct exec CONTAINER_ID -- df -h
```

Confirm that the container can reach GitHub:

```bash
pct exec CONTAINER_ID -- curl -I https://github.com
```

Review the installer output for the failing Git command.

</details>

---

## File Locations

| Purpose | Path inside the container |
|:--|:--|
| 5eTools source | `/opt/5etools-src` |
| Image repository | `/opt/5etools-src/img` |
| Image helper | `/opt/install-5etools-img.sh` |
| Manual updater | `/usr/bin/update` |
| Main service | `/etc/systemd/system/5etools.service` |
| Update service | `/etc/systemd/system/5etools-update.service` |
| Update timer | `/etc/systemd/system/5etools-update.timer` |
| Update log | `/var/log/5etools-update.log` |

---

## Uninstalling

> [!CAUTION]
> Destroying the container permanently removes 5eTools and all data stored inside the container.

Stop and destroy the container:

```bash
pct stop CONTAINER_ID
pct destroy CONTAINER_ID
```

Verify the container ID before running these commands.

---

## Upstream Projects

This installer deploys content from:

- [5etools-mirror-3/5etools-src](https://github.com/5etools-mirror-3/5etools-src)
- [5etools-mirror-3/5etools-img](https://github.com/5etools-mirror-3/5etools-img)

This repository is an independent deployment helper and is not affiliated with Wizards of the Coast or the upstream 5eTools maintainers.

---

## License

The installer script is provided under the MIT License.

The upstream 5eTools source code, data, images, trademarks, and game content may be governed by separate licenses or terms. Review the relevant upstream repositories before redistributing content.
