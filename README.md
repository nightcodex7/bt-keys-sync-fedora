# bt-keys-sync

Dual-boot Bluetooth pairing key synchronizer between Linux and Windows, optimized for **Fedora KDE 44+** and compatible with modern Linux distributions.

**Version:** 2.0.0  
**Author:** nightcodex7  
**License:** GNU General Public License v3.0 ([GPL-3.0](https://opensource.org/licenses/GPL-3.0))  
**Repository:** [nightcodex7/bt-keys-sync-fedora](https://github.com/nightcodex7/bt-keys-sync-fedora)

---

## Table of Contents

- [Overview](#overview)
- [The Dual-Boot Problem](#the-dual-boot-problem)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Recommended Workflow](#recommended-workflow)
- [Usage & CLI Options](#usage--cli-options)
- [Bluetooth Low Energy (BLE)](#bluetooth-low-energy-ble)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Overview

When dual-booting Linux and Windows on the same PC, Bluetooth devices (mice, keyboards, headphones) often lose their connection whenever you switch operating systems. `bt-keys-sync` resolves this by reading pairing keys across both systems, identifying discrepancies, and allowing you to synchronize the latest valid key without repeatedly re-pairing your devices.

---

## The Dual-Boot Problem

When pairing a Bluetooth device, the device and the host OS negotiate a unique authentication Link Key. Because the Bluetooth adapter has the same MAC address regardless of which OS is running:

1. Pairing a device in Windows creates key **A** in the Windows Registry.
2. Booting into Linux and pairing the same device generates a new key **B** in `/var/lib/bluetooth/`.
3. The peripheral replaces key **A** in its internal memory with key **B**.
4. Booting back into Windows fails because Windows attempts to use key **A**, which the peripheral no longer recognizes.

`bt-keys-sync` compares paired devices between both systems, detects mismatched keys, and copies the active key from one OS to the other.

---

## Features

- **Automated Registry Detection**: Automatically searches `/media`, `/mnt`, and `/run/media` for the Windows `SYSTEM` hive.
- **Clean Service Reloading**: Automatically stops the `bluetooth.service` before updating Linux pairing keys and safely restarts it, applying changes immediately without a reboot.
- **Safety First**: Creates automatic timestamped backups of the Windows `SYSTEM` hive before making any registry modifications.
- **Batch Sync Modes**: Supports non-interactive flags (`--windows-keys` / `--linux-keys`) for scripted workflows.
- **Inspection Mode**: List all paired adapters, remote devices, and stored keys without modifying anything (`--only-list`).

---

## Prerequisites

- **chntpw** (for reading and writing Windows registry hives)
- Root/sudo privileges (required to access `/var/lib/bluetooth/` and Windows registry hives)
- Windows partition mounted with **read and write** permissions (Fast Startup and BitLocker hibernation must be disabled in Windows)

### Package Installation

**Fedora:**
```bash
sudo dnf install chntpw
```

**Debian / Ubuntu:**
```bash
sudo apt install chntpw
```

**Arch Linux:**
```bash
sudo pacman -S chntpw
```

---

## Installation

### Option 1: Direct System Install (Recommended)

```bash
curl -fsSL -o /tmp/bt-keys-sync.sh 'https://raw.githubusercontent.com/nightcodex7/bt-keys-sync-fedora/main/bt-keys-sync.sh'
sudo mkdir -p /opt/bt-keys-sync/
sudo install -m 755 /tmp/bt-keys-sync.sh /opt/bt-keys-sync/bt-keys-sync.sh
sudo ln -sf /opt/bt-keys-sync/bt-keys-sync.sh /usr/local/bin/bt-keys-sync
rm -f /tmp/bt-keys-sync.sh
```

### Option 2: Run from Cloned Repository

```bash
git clone https://github.com/nightcodex7/bt-keys-sync-fedora.git
cd bt-keys-sync-fedora
chmod +x bt-keys-sync.sh
sudo ./bt-keys-sync.sh
```

---

## Recommended Workflow

> [!TIP]
> **Importing keys from Windows to Linux is the safest and recommended approach**, as modifying Linux configuration files is simpler and poses no risk to the Windows registry.

1. **Pair on Linux first**: Boot into Linux and pair all your Bluetooth devices normally.
2. **Pair on Windows**: Reboot into Windows, remove any old pairings, and pair all the same devices again so Windows holds the newest valid link keys.
3. **Mount the Windows drive**: Boot back into Linux and ensure your Windows drive is mounted (e.g. open the drive in Dolphin / file manager, or mount via `/etc/fstab`).
4. **Sync keys to Linux**:
   Run `bt-keys-sync`:
   ```bash
   sudo bt-keys-sync --windows-keys
   ```
   Or run without flags to inspect and choose interactively:
   ```bash
   sudo bt-keys-sync
   ```

---

## Usage & CLI Options

```text
Usage: bt-keys-sync [OPTIONS]
```

| Option | Long Option | Description |
| :--- | :--- | :--- |
| `-p <path>` | `--path <path>` | Specify full path to the Windows `SYSTEM` registry hive file |
| `-c <name>` | `--control-set <name>` | Registry control set to query (default: `ControlSet001`) |
| `-w` | `--windows-keys` | Import keys from Windows to Linux non-interactively |
| `-l` | `--linux-keys` | Import keys from Linux to Windows non-interactively |
| `-o` | `--only-list` | Only list detected adapters, devices, and pairing keys |
| `-h` | `--help` | Display usage instructions and exit |

### Examples

**Interactive Mode:**
```bash
sudo bt-keys-sync
```

**List paired devices and keys without modifying anything:**
```bash
sudo bt-keys-sync --only-list
```

**Specify custom path to Windows SYSTEM hive:**
```bash
sudo bt-keys-sync --path "/run/media/$USER/Windows/Windows/System32/config/SYSTEM"
```

**Automatically sync Windows keys to Linux:**
```bash
sudo bt-keys-sync --windows-keys
```

---

## Bluetooth Low Energy (BLE)

BLE (Bluetooth Smart / 4.0+) devices use different key distribution formats (IRK, CSRK, LTK) compared to Classic Bluetooth Link Keys. 
- Classical Bluetooth devices (BR/EDR) are fully supported for validation and synchronization.
- BLE devices can be detected, but synchronization is currently experimental. Refer to the project [issues](https://github.com/nightcodex7/bt-keys-sync-fedora/issues) for updates and discussion.

---

## Troubleshooting

### Windows partition is read-only
If Linux mounts your Windows NTFS partition as read-only:
1. Boot into Windows.
2. Open **Control Panel** $\to$ **Power Options** $\to$ **Choose what the power buttons do**.
3. Click *Change settings that are currently unavailable* and **disable Fast Startup**.
4. Shut down Windows completely (do not Hibernate) before booting back into Linux.

### SYSTEM hive not found automatically
If the script does not locate your Windows partition, mount it via your desktop file manager or terminal, locate the `SYSTEM` hive, and pass the explicit path with `-p`:
```bash
sudo bt-keys-sync -p "/path/to/mount/Windows/System32/config/SYSTEM"
```

### Restoring Windows Registry Backup
When writing keys from Linux to Windows, the script creates a backup in the same directory:
`SYSTEM_BACKUP_<YYYYMMDD_HHMMSS>`
If you ever need to restore:
```bash
sudo cp /path/to/SYSTEM_BACKUP_<timestamp> /path/to/SYSTEM
```

---

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file or [GNU GPL v3.0](https://opensource.org/licenses/GPL-3.0) for details.
