# bt-keys-sync

# Version:    0.3.10
# Author:     KeyofBlueS
# Repository: https://github.com/KeyofBlueS/bt-keys-sync
# License:    GNU General Public License v3.0, https://opensource.org/licenses/GPL-3.0

### ☕️ [If you like what I do, consider buying me a coffee, it really helps!](https://ko-fi.com/keyofblues) ☕️

### DESCRIPTION
When you pair a Bluetooth device with an operating system, a unique authentication key is generated. In a multi-boot setup, only the OS where the device was last paired holds the latest working key. This means you'll need to re-pair the device on any other system, as they won't recognize the new key. This behavior applies across all operating systems, Linux, Windows, or others.

This script is designed for dual-boot environments involving Linux and Windows. It compares the paired Bluetooth devices between the two systems. If it finds mismatched pairing keys for a device, it will prompt you to choose which key to use (typically, the system where you last paired the device has the current valid key). The script will then update the older key with the selected one.

Recommended Workflow:
Importing Bluetooth keys from Windows to Linux is generally safe. However, the reverse, importing from Linux to Windows, can be risky, as it involves modifying the Windows registry. For best results:

1. Pair your Bluetooth devices in Linux first.
2. Boot into Windows, remove any existing pairings, and re-pair the devices so that Windows stores the updated keys.
3. Boot back into Linux and run `bt-keys-sync`, choosing the "`Windows key`" when prompted, or use the `--windows-keys` option to automate the process.

**Warning:**
If you choose to import keys from Linux to Windows `(tested only on Windows 10 and 11)`, proceed at your own risk. The script will back up the Windows SYSTEM registry hive file before making changes, allowing you to restore it in case of any issues.

### About Bluetooth Low Energy (BLE)
BLE devices can be detected, but their keys will not be validated or synchronized.
For more information on BLE handling, please refer to [this issue](https://github.com/KeyofBlueS/bt-keys-sync/issues/13).

### INSTALL
```
curl -o /tmp/bt-keys-sync.sh 'https://raw.githubusercontent.com/KeyofBlueS/bt-keys-sync/master/bt-keys-sync.sh'
sudo mkdir -p /opt/bt-keys-sync/
sudo mv /tmp/bt-keys-sync.sh /opt/bt-keys-sync/
sudo chown root:root /opt/bt-keys-sync/bt-keys-sync.sh
sudo chmod 755 /opt/bt-keys-sync/bt-keys-sync.sh
sudo chmod +x /opt/bt-keys-sync/bt-keys-sync.sh
sudo ln -s /opt/bt-keys-sync/bt-keys-sync.sh /usr/local/bin/bt-keys-sync
```

This script requires the `chntpw` utility, which is used to read and modify Windows registry files. You can install it on most Debian-based systems using:

`sudo apt install chntpw`

### USAGE
Before running the script, make sure the Windows partition is mounted with read and write access.

To run the script, simply execute:

`$ bt-keys-sync`

The script will automatically search for the Windows `SYSTEM` registry hive file within common mount points such as `/media` and `/mnt`. If it cannot locate the file, you will need to manually provide the full path. This path typically looks like:

`"<windows_mount_point>/Windows/System32/config/SYSTEM"`

To skip the automatic search, use the `--path` option followed by the path to the registry hive:

`$ bt-keys-sync --path "<windows_mount_point>/Windows/System32/config/SYSTEM"`

By default, the script checks ControlSet001 in the registry. You can specify a different control set using the `--control-set option`.

```
Options:
-p, --path <system_hive_path>    Enter the full path of the windows SYSTEM registry hive file.
-c, --control-set <control_set>  Enter the control set to check. Default is 'ControlSet001'.
-l, --linux-keys                 Import bluetooth pairing keys from linux to windows without asking.
-w, --windows-keys               Import bluetooth pairing keys from windows to linux without asking.
-o, --only-list                  Only list bluetooth devices and pairing keys, don't do anything else.
-h, --help                       Show this help.
```
