<div align="center">

# Proxmox 5eTools Installer

### Deploy a self-hosted 5eTools server in a Proxmox LXC container

[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-VE-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Debian](https://img.shields.io/badge/Debian-12%20%7C%2013-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Node.js](https://img.shields.io/badge/Node.js-24-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#license)

A guided installer that creates a Proxmox LXC container, installs 5eTools, optionally downloads image assets, configures automatic updates, and starts the web server.

</div>

---

## Overview

Launch the installer once, choose the deployment options, and let it complete the rest automatically.

### The installer can

- Create an unprivileged Debian 12 or Debian 13 LXC container
- Select the newest available matching Proxmox template
- Install Node.js 24 and required dependencies
- Clone and prepare the 5eTools source
- Optionally download the complete image repository
- Optionally enable nightly automatic updates
- Use a user-selected web port
- Create and enable the systemd service
- Start 5eTools and verify that it responds
- Clean temporary files and package caches after installation
- Roll back a newly created container if installation fails

> [!IMPORTANT]
> Run the installer from the **Proxmox host shell as root**.  
> Do not run it from inside another container or virtual machine.

> [!NOTE]
> Current 5eTools releases require **Node.js 24 or newer**. The installer configures NodeSource 24.x and verifies the installed major version before continuing.

---

## Quick Start

Run the installer directly from the Proxmox host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)"
```

The installer presents all deployment choices at startup. After the selections are made, no additional commands or input are required.

---

## Installation Options

The initial setup allows the user to choose:

| Option | Choices |
|:--|:--|
| Debian release | Debian 12 Bookworm or Debian 13 Trixie |
| Image repository | Install or skip |
| Automatic updates | Enable or disable |
| Web port | Any valid TCP port from `1` to `65535` |

After the selections are confirmed, the installer continues automatically and starts 5eTools when setup finishes.

> [!TIP]
> The default port is `5050`, but any unused TCP port can be selected during installation.

---

## Unattended Installation

### Default Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- --defaults
```

### Debian 13

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" -- --defaults --debian 13
```

### Images and Custom Port

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" --   --defaults   --images   --port 8080
```

### Debian 13, Images, and Custom Port

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" --   --defaults   --debian 13   --images   --port 8080
```

### Specific Container ID

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" --   120   --defaults   --debian 12
```

### Supported Options

| Option | Purpose |
|:--|:--|
| `--defaults` | Skip the interactive installer menus |
| `--debian 12` | Use Debian 12 Bookworm |
| `--debian 13` | Use Debian 13 Trixie |
| `--images` | Download the complete image repository |
| `--port PORT` | Set the 5eTools web server port |
| Container ID argument | Use a specific Proxmox container ID |

> [!WARNING]
> A manually selected container ID must not already exist.

---

## Default Configuration

| Setting | Default value |
|:--|:--|
| Hostname | `5etools` |
| Debian version | Debian 12 Bookworm |
| Container type | Unprivileged LXC |
| Container ID | Next available ID |
| Container storage | `local-lvm` |
| Template storage | `local` |
| Template version | Newest available matching release |
| Disk size | 20 GB |
| Memory | 2048 MB |
| CPU cores | 2 |
| Network bridge | `vmbr0` |
| IP configuration | DHCP |
| Web port | `5050` |
| Image repository | User-selectable |
| Automatic updates | User-selectable |
| Service startup | Automatic |

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
- A Debian 12 or Debian 13 template available through `pveam`
- At least 20 GB of free storage
- Additional free space when installing image assets

Check available storage:

```bash
pvesm status
```

Check available bridges:

```bash
ip link show
```

Check available Debian templates:

```bash
pveam update
pveam available --section system | grep debian
```

---

## What the Installer Does

1. Verifies that it is running as root on a Proxmox VE host
2. Collects Debian, image, update, and port choices
3. Selects or accepts a container ID
4. Locates or downloads the newest matching Debian template
5. Creates an unprivileged LXC container
6. Starts the container and waits for networking
7. Updates Debian packages
8. Installs Git, curl, certificates, GnuPG, and Node.js 24
9. Verifies that Node.js 24 or newer is installed
10. Clones the 5eTools source into `/opt/5etools-src`
11. Installs Node.js dependencies
12. Builds the production service worker
13. Downloads image assets when selected
14. Creates the 5eTools systemd service
15. Creates update tooling when selected
16. Enables and starts the service
17. Verifies that the chosen web port responds
18. Cleans temporary files and package caches
19. Displays the final URL, container ID, and generated password

> [!NOTE]
> If installation fails after the container is created, the installer can stop and destroy that newly created container so a partial deployment is not left behind.

---

## Accessing 5eTools

When installation finishes, the script displays:

- Container ID
- Container IP address
- Generated root password
- Debian release
- Image installation status
- Automatic update status
- Browser URL

Open the displayed address:

```text
http://CONTAINER-IP:PORT/index.html
```

Example:

```text
http://192.168.1.50:5050/index.html
```

The selected port is written into the systemd service and used by the post-install health check.

---

## Image Assets

The optional image repository contains monster artwork, maps, spell illustrations, and other assets.

Select the image option during interactive installation, or run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gmoran1016/proxmox-5etools/main/install.sh)" --   --defaults   --images
```

> [!CAUTION]
> The image repository can require approximately **5–7 GB** of additional disk space and can significantly increase installation time.

---

## Automatic Updates

When enabled, a systemd timer runs nightly at approximately `01:00`, with a randomized delay of up to five minutes.

Each update:

1. Stops the 5eTools service
2. Pulls the latest source changes
3. Updates image assets when installed
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

---

## Service Management

### Check Status

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

The interactive installer exposes the most common settings directly:

- Debian 12 or Debian 13
- Image installation
- Automatic updates
- Web port

Additional defaults can be edited near the top of `install.sh`:

```bash
CT_HOSTNAME="5etools"
CT_STORAGE="local-lvm"
CT_DISK="20"
CT_RAM="2048"
CT_CPU="2"
CT_BRIDGE="vmbr0"
CT_OS_STORAGE="local"
DEBIAN_VERSION="12"
SERVE_PORT="5050"
```

The Debian template filename is not hardcoded. The installer queries Proxmox and selects the newest matching `amd64` template for the chosen Debian release.

---

## Cleanup and Rollback

### Successful Installation

After installation, the script removes:

- APT package caches
- Stale package lists
- npm download cache
- Temporary installer files
- Unused packages when safe to remove

The 5eTools application, image assets, service files, logs, and update tools are preserved.

### Failed Installation

If the installer fails after creating a new container, it can:

- Stop the partially configured container
- Destroy the newly created container
- Purge the associated container configuration

Existing containers are never removed because the installer checks the selected container ID before creation.

---

## Troubleshooting

<details>
<summary><strong><code>pct not found</code></strong></summary>

The installer is not running directly on a Proxmox VE host.

Run it from the Proxmox host shell as root.

</details>

<details>
<summary><strong>No matching Debian template is found</strong></summary>

Refresh the appliance catalog:

```bash
pveam update
```

List available Debian templates:

```bash
pveam available --section system | grep debian
```

Confirm that the chosen release is available and that `CT_OS_STORAGE` supports LXC templates.

</details>

<details>
<summary><strong>Configured storage does not exist</strong></summary>

List available storage targets:

```bash
pvesm status
```

Update the installer defaults:

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
<summary><strong>The selected web port is unavailable</strong></summary>

Choose another port during installation or use:

```bash
--port 8080
```

Check listening ports inside the container:

```bash
pct exec CONTAINER_ID -- ss -lntp
```

</details>

<details>
<summary><strong>The container has no IP address</strong></summary>

Inspect networking:

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

View service logs:

```bash
pct exec CONTAINER_ID -- journalctl -u 5etools -n 100 --no-pager
```

Also verify that the selected TCP port is allowed through any Proxmox, container, host, router, or client firewall.

</details>

<details>
<summary><strong>Node.js version is unsupported</strong></summary>

Check the installed version:

```bash
pct exec CONTAINER_ID -- node -v
```

Current 5eTools releases require Node.js 24 or newer.

</details>

---

## File Locations

| Purpose | Path inside the container |
|:--|:--|
| 5eTools source | `/opt/5etools-src` |
| Image repository | `/opt/5etools-src/img` |
| Manual updater | `/usr/bin/update` |
| Main service | `/etc/systemd/system/5etools.service` |
| Update service | `/etc/systemd/system/5etools-update.service` |
| Update timer | `/etc/systemd/system/5etools-update.timer` |
| Install log | `/var/log/5etools-install.log` |
| Update log | `/var/log/5etools-update.log` |

---

## Uninstalling

> [!CAUTION]
> Destroying the container permanently removes 5eTools and all data stored inside it.

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

This project is an independent deployment helper and is not affiliated with Wizards of the Coast or the upstream 5eTools maintainers.

---

## License

The installer script is provided under the MIT License.

The upstream 5eTools source code, data, images, trademarks, and game content may be governed by separate licenses or terms. Review the relevant upstream repositories before redistributing content.
