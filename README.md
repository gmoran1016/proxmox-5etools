<div align="center">

# Proxmox 5eTools Installer

### Deploy a self-hosted 5eTools instance in a Proxmox LXC container

[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-VE-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Debian](https://img.shields.io/badge/Debian-12-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Node.js](https://img.shields.io/badge/Node.js-22-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#license)

A standalone Bash installer that creates an unprivileged Debian 12 LXC container, installs 5eTools, configures it as a systemd service, and enables automatic nightly updates.

</div>

---

## Overview

This project automates the deployment of a local 5eTools server on Proxmox VE.

The installer:

- Creates a new unprivileged LXC container
- Installs Node.js 22 and required packages
- Clones and prepares the 5eTools source
- Runs 5eTools as a systemd service
- Makes the site available on port `5050`
- Creates optional image-download tooling
- Enables nightly automatic updates

> [!IMPORTANT]
> Run the installer from the **Proxmox host shell as root**.  
> Do not run it from inside an existing LXC container or virtual machine.

---

## Quick Start

Run the following commands on your Proxmox host:

```bash
wget -O 5etools-standalone.sh   https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/5etools-standalone.sh

chmod +x 5etools-standalone.sh
bash 5etools-standalone.sh
```

The installer will display the proposed container settings and ask for confirmation before creating anything.

After installation, open:

```text
http://CONTAINER-IP:5050/index.html
```

---

## Default Configuration

| Setting | Default value |
|:--|:--|
| Hostname | `5etools` |
| Operating system | Debian 12 |
| Container type | Unprivileged LXC |
| Storage | `local-lvm` |
| Template storage | `local` |
| Disk size | 20 GB |
| Memory | 2048 MB |
| CPU cores | 2 |
| Network bridge | `vmbr0` |
| IP configuration | DHCP |
| Web port | `5050` |
| Automatic updates | Daily at approximately 1:00 AM |

> [!NOTE]
> The default values can be changed near the top of `5etools-standalone.sh` before installation.

---

## Requirements

Before running the installer, confirm that the Proxmox host has:

- Proxmox VE installed and working
- Root shell access
- Internet connectivity
- A storage target named `local-lvm`
- Template storage named `local`
- A Linux bridge named `vmbr0`
- DHCP available on the selected network
- At least 20 GB of free storage

Check your Proxmox storage configuration:

```bash
pvesm status
```

Check available network interfaces and bridges:

```bash
ip link show
```

If your environment uses different names, update the variables in the installer before running it.

---

## Installation Options

### Automatic Container ID

When no container ID is supplied, the installer requests the next available ID from Proxmox:

```bash
bash 5etools-standalone.sh
```

### Specific Container ID

Pass the desired container ID as the first argument:

```bash
bash 5etools-standalone.sh 120
```

> [!WARNING]
> The selected container ID must not already be in use.

---

## What the Installer Creates

The installer performs the following operations:

1. Downloads the configured Debian 12 LXC template if needed
2. Creates an unprivileged LXC container
3. Starts the container and updates Debian
4. Installs Git, curl, certificates, GnuPG, and Node.js 22
5. Clones the 5eTools source into `/opt/5etools-src`
6. Installs Node.js dependencies
7. Builds the production service worker
8. Creates the `5etools.service` systemd unit
9. Creates an optional image repository helper
10. Creates a manual update command at `/usr/bin/update`
11. Creates and enables a nightly systemd update timer

---

## Accessing 5eTools

When installation finishes, the script prints:

- Container ID
- Container IP address
- Generated root password
- Browser URL
- Update and image-download commands

Open the displayed address in a browser:

```text
http://CONTAINER-IP:5050/index.html
```

Example:

```text
http://192.168.1.50:5050/index.html
```

---

## Optional Image Repository

The default installation does not download the complete 5eTools image repository.

To download monster artwork, maps, spell illustrations, and other image assets, run:

```bash
pct exec CONTAINER_ID -- bash /opt/install-5etools-img.sh
```

Restart the service afterward:

```bash
pct exec CONTAINER_ID -- systemctl restart 5etools
```

> [!CAUTION]
> The image repository can use approximately **5–7 GB** of additional disk space.

---

## Updating 5eTools

### Automatic Updates

A systemd timer runs nightly at approximately `01:00`, with a randomized delay of up to five minutes.

Each automatic update:

1. Stops the 5eTools service
2. Pulls the latest source changes
3. Updates the image repository when installed
4. Runs `npm install`
5. Rebuilds the service worker
6. Restarts the service

### Manual Update

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

## Service Management

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

Edit these variables near the top of `5etools-standalone.sh`:

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
> If Proxmox offers a newer Debian 12 template under a different filename, update `CT_OS_TEMPLATE` before running the installer.

---

## Troubleshooting

<details>
<summary><strong><code>pct not found</code></strong></summary>

The installer is not running directly on a Proxmox VE host.

Run it from the Proxmox host shell as root.

</details>

<details>
<summary><strong>Configured storage does not exist</strong></summary>

List available storage targets:

```bash
pvesm status
```

Update these installer variables as needed:

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

Inspect the container network configuration:

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

Check the application service:

```bash
pct exec CONTAINER_ID -- systemctl status 5etools
```

Check listening ports:

```bash
pct exec CONTAINER_ID -- ss -lntp
```

Review service logs:

```bash
pct exec CONTAINER_ID -- journalctl -u 5etools -n 100 --no-pager
```

Also confirm that any Proxmox, container, router, or host firewall allows TCP port `5050`.

</details>

---

## Uninstalling

> [!DANGER]
> Destroying the container permanently removes the 5eTools installation and all data stored inside that container.

Stop and destroy the container:

```bash
pct stop CONTAINER_ID
pct destroy CONTAINER_ID
```

Verify the container ID before running these commands.

---

## File Locations

| Purpose | Path inside the container |
|:--|:--|
| 5eTools source | `/opt/5etools-src` |
| Image helper | `/opt/install-5etools-img.sh` |
| Manual updater | `/usr/bin/update` |
| Main service | `/etc/systemd/system/5etools.service` |
| Update service | `/etc/systemd/system/5etools-update.service` |
| Update timer | `/etc/systemd/system/5etools-update.timer` |
| Update log | `/var/log/5etools-update.log` |

---

## Upstream Projects

This installer deploys content from:

- [5etools-mirror-3/5etools-src](https://github.com/5etools-mirror-3/5etools-src)
- [5etools-mirror-3/5etools-img](https://github.com/5etools-mirror-3/5etools-img)

This project is an independent deployment helper and is not affiliated with Wizards of the Coast or the upstream 5eTools maintainers.

---

## License

The installer script is provided under the MIT License.

The upstream 5eTools source code, data, images, trademarks, and game content may be governed by separate licenses or terms. Review the relevant upstream repositories before redistributing any content.
