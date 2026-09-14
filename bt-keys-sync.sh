#!/bin/bash

# bt-keys-sync

# Version:    2.0.0
# Author:     nightcodex7
# Github:     https://github.com/nightcodex7
# Repository: https://github.com/nightcodex7/bt-keys-sync-fedora
# License:    GNU General Public License v3.0, https://opensource.org/licenses/GPL-3.0


function check_bt_controllers() {
	check_sudo
	bt_controllers_linux="$(sudo ls "/var/lib/bluetooth/" 2>/dev/null | grep -Eo "^([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}$")"
	bt_controllers_windows="$(cat "${tmp_dir}/${tmp_reg}" 2>/dev/null | tr -d '\r' | grep -Fi "HKEY_LOCAL_MACHINE\SYSTEM\\${control_set}\Services\BTHPORT\Parameters\Keys" | tr '\\\\' '/' | awk -F'/' '{print $8}' | grep -Eo "([[:xdigit:]]){12}" | sort -u)"

	bt_controllers_reg="${bt_controllers_linux//:/}\n${bt_controllers_windows}"

	bt_controllers="$(echo -e "${bt_controllers_reg,,}" | sort -u)"

	if [[ -z "${bt_controllers}" ]]; then
		echo -e "\e[1;33m* no bluetooth controllers found in linux or windows registry.\e[0m"
		return
	fi

	for bt_controller in ${bt_controllers}; do
		bt_controller_macaddr="$(echo "${bt_controller^^}" | sed 's/.\{2\}/&:/g' | sed 's/.$//')"
		bt_controller_linux="$(echo "${bt_controllers_linux}" | grep -i "^${bt_controller_macaddr}$")"
		bt_controller_windows="$(echo "${bt_controllers_windows}" | grep -i "^${bt_controller}$")"
		echo
		echo "- bluetooth controller: ${bt_controller_macaddr}"
		if [[ -z "${bt_controller_linux}" ]]; then
			echo -e "\e[1;31m* bluetooth controller not found in linux\e[0m"
		fi
		if [[ -z "${bt_controller_windows}" ]]; then
			echo -e "\e[1;31m* bluetooth controller not found in windows\e[0m"
		fi
		check_bt_devices
	done
}

function check_bt_devices() {

	unset bt_devices_linux
	if [[ -n "${bt_controller_linux}" ]]; then
		check_sudo
		bt_devices_linux="$(sudo ls "/var/lib/bluetooth/${bt_controller_linux}" 2>/dev/null | grep -Eo "^([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}$")"
	fi

	unset bt_devices_windows
	if [[ -n "${bt_controller_windows}" ]]; then
		bt_devices_windows="$(cat "${tmp_dir}/${tmp_reg}" 2>/dev/null | tr -d '\r' | awk -v ctrl="${bt_controller_windows}" 'tolower($0) ~ tolower("\\[.*Keys\\\\" ctrl "\\]") { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }' | awk -F'"' '{print $2}' | grep -Eo "^([[:xdigit:]]){12}$")\n"
		bt_devices_windows+="$(cat "${tmp_dir}/${tmp_reg}" 2>/dev/null | tr -d '\r' | grep -Fi "HKEY_LOCAL_MACHINE\SYSTEM\\${control_set}\Services\BTHPORT\Parameters\Keys\\${bt_controller_windows}" | tr '\\\\' '/' | awk -F'/' '{print $9}' | grep -Eo "([[:xdigit:]]){12}")"
		bt_devices_windows="$(echo -e "${bt_devices_windows}" | grep -v '^$' | sort -u)"
	fi

	bt_devices_reg="${bt_devices_linux//:/}\n${bt_devices_windows}"

	bt_devices="$(echo -e "${bt_devices_reg,,}" | sort -u)"

	for bt_device in ${bt_devices}; do
		bt_device_macaddr="$(echo "${bt_device^^}" | sed 's/.\{2\}/&:/g' | sed 's/.$//')"
		bt_device_linux="$(echo "${bt_devices_linux}" | grep -i "^${bt_device_macaddr}$")"
		bt_device_windows="$(echo "${bt_devices_windows}" | grep -i "^${bt_device}$")"

		if [[ -n "${bt_device_linux}" ]]; then
			check_sudo
			bt_device_info="$(sudo cat "/var/lib/bluetooth/${bt_controller_linux}/${bt_device_linux}/info" 2>/dev/null)"
			bt_device_name="$(echo "${bt_device_info}" | grep '^Alias=' | awk -F'=' '{print $2}')"
			if [[ -z "${bt_device_name}" ]]; then
				bt_device_name="$(echo "${bt_device_info}" | grep '^Name=' | awk -F'=' '{print $2}')"
			fi
			if [[ -z "${bt_device_name}" ]]; then
				bt_device_name='UNKNOWN'
			fi
		elif [[ -n "${bt_device_windows}" ]]; then
			if [[ "${tmp_devs_deployed}" != 'true' ]]; then
				tmp_devs_deployed='true'
				check_sudo
				sudo reged -x "${tmp_dir}/${tmp_hive}" "HKEY_LOCAL_MACHINE\SYSTEM" "\\${control_set}\Services\BTHPORT\Parameters\Devices" "${tmp_dir}/${tmp_devs}" >/dev/null 2>&1
				bt_devices_info_devs_reg="$(cat "${tmp_dir}/${tmp_devs}" 2>/dev/null | tr -d '\r')"
			fi
			bt_device_info_devs_reg="$(echo "${bt_devices_info_devs_reg}" | awk -v dev="${bt_device_windows}" 'tolower($0) ~ tolower("\\[.*Devices\\\\" dev "\\]") { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }')"
			bt_device_name="$(echo "${bt_device_info_devs_reg}" | grep -Fi '"FriendlyName"=' | grep -Eo "([[:xdigit:]]{1,2},)+[[:xdigit:]]{2}$")"
			if [[ -z "${bt_device_name}" ]]; then
				bt_device_name="$(echo "${bt_device_info_devs_reg}" | grep -Fi '"Name"=' | grep -Eo "([[:xdigit:]]{1,2},)+[[:xdigit:]]{2}$")"
			fi
			if [[ -n "${bt_device_name}" ]]; then
				bt_device_name="$(python3 -c "import sys; b=bytes.fromhex(''.join(sys.argv[1].split(','))); print(b.decode('utf-16le', errors='ignore').rstrip('\x00'))" "${bt_device_name}" 2>/dev/null)"
			fi
			if [[ -z "${bt_device_name}" ]]; then
				bt_device_name="$(echo "${bt_device_info_devs_reg}" | grep -Fi '"FriendlyName"=' | cut -d'"' -f4)"
			fi
			if [[ -z "${bt_device_name}" ]]; then
				bt_device_name="$(echo "${bt_device_info_devs_reg}" | grep -Fi '"Name"=' | cut -d'"' -f4)"
			fi
			if [[ -z "${bt_device_name}" ]]; then
				bt_device_name='UNKNOWN'
			fi
		fi
		echo
		echo "	\- bluetooth device: ${bt_device_macaddr} - ${bt_device_name}"

		unset bt_device_type_linux
		unset key_lk_linux
		unset key_irk_linux
		unset key_lsk_linux
		unset key_ltk_linux
		unset key_ediv_linux
		unset key_rand_linux
		unset key_lk_linux_reg
		unset key_irk_linux_reg
		unset key_lsk_linux_reg
		unset key_ltk_linux_reg
		unset key_ediv_linux_reg
		unset key_rand_linux_reg
		unset bt_device_type_windows
		unset key_lk_windows
		unset key_irk_windows
		unset key_lsk_windows
		unset key_ltk_windows
		unset key_ediv_windows
		unset key_rand_windows
		unset key_lk_windows_reg
		unset key_irk_windows_reg
		unset key_lsk_windows_reg
		unset key_ltk_windows_reg
		unset key_ediv_windows_reg
		unset key_rand_windows_reg
		unset nokey
		unset bt_device_type
		if [[ -z "${bt_device_linux}" ]]; then
			echo -e "\e[1;31m		* bluetooth device not found in linux. Please pair this device in linux.\e[0m"
			nokey='1'
		else
			check_bt_device_type_linux
			if [[ "${bt_device_type_linux}" = 'standard' ]]; then # delete after BLE support will be implemented
				get_bt_keys_linux
			fi # delete after BLE support will be implemented
		fi
		if [[ -z "${bt_device_windows}" ]]; then
			echo -e "\e[1;31m		* bluetooth device not found in windows. Please pair this device in windows.\e[0m"
			nokey='1'
		else
			check_bt_device_type_windows
			if [[ "${bt_device_type_windows}" = 'standard' ]]; then
				bt_device_info_keys_reg="$(cat "${tmp_dir}/${tmp_reg}" 2>/dev/null | tr -d '\r' | awk -v ctrl="${bt_controller_windows}" 'tolower($0) ~ tolower("\\[.*Keys\\\\" ctrl "\\]") { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }' | grep -Fi "\"${bt_device_windows}\"=hex:" | grep -Eo "([[:xdigit:]]{1,2},){15}[[:xdigit:]]{2}$")"
			elif [[ "${bt_device_type_windows}" = 'ble' ]]; then
				bt_device_info_keys_reg="$(cat "${tmp_dir}/${tmp_reg}" 2>/dev/null | tr -d '\r' | awk -v ctrl="${bt_controller_windows}" -v dev="${bt_device_windows}" 'tolower($0) ~ tolower("\\[.*Keys\\\\" ctrl "\\\\" dev "\\]") { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }')"
			fi
			if [[ "${bt_device_type_windows}" = 'standard' ]]; then # delete after BLE support will be implemented
				get_bt_keys_windows
			fi # delete after BLE support will be implemented
		fi
		if [[ "${bt_device_type_linux}" = 'standard' ]] && [[ "${bt_device_type_windows}" = 'standard' ]]; then
			bt_device_type='standard'
		elif [[ "${bt_device_type_linux}" = 'ble' ]] && [[ "${bt_device_type_windows}" = 'ble' ]]; then
			bt_device_type='ble'
		elif [[ "${bt_device_type_linux}" = 'standard' ]] && [[ "${bt_device_type_windows}" = 'ble' ]] || [[ "${bt_device_type_linux}" = 'ble' ]] && [[ "${bt_device_type_windows}" = 'standard' ]]; then
			echo -e "\e[1;31m		* error: mismatch between device type!\e[0m"
			continue
		fi
		##############################################################
		# delete after BLE support will be implemented
		if [[ "${bt_device_type_linux}" = 'ble' ]] || [[ "${bt_device_type_windows}" = 'ble' ]]; then
			echo -e "\e[1;31m		* this device appear to be a Bluetooth Low Energy Device (BLE)\e[0m"
			echo -e "\e[1;31m		* support for Bluetooth Low Energy Devices is currently unimplemented\e[0m"
			echo -e "\e[1;34m		* please take a look at: https://github.com/nightcodex7/bt-keys-sync-fedora/issues\e[0m"
			continue
		fi
		##############################################################
		if [[ "${nokey}" = '1' ]]; then
			nokey_warn='1'
			continue
		else
			compare_bt_keys
			if [[ "${different}" != 'true' ]]; then
				noerror='1'
				echo -e "\e[1;32m		* keys are synced\e[0m"
			else
				bt_keys_sync_common
			fi
		fi
	done
}

function check_bt_device_type_linux() {

	unset bt_device_type_linux
	if echo "${bt_device_info}" | grep -Eq "^\[LinkKey\]$"; then
		bt_device_type_linux='standard'
	elif [[ "$(echo "${bt_device_info}" | grep -Ei "^(\[IdentityResolvingKey\]|\[LocalSignatureKey\]|\[LongTermKey\]|\[PeripheralLongTermKey\]|\[SlaveLongTermKey\]|EncSize|EDiv|Rand)" | wc -l)" -ge '5' ]]; then
		bt_device_type_linux='ble'
	fi
}

function check_bt_device_type_windows() {

	unset bt_device_type_windows
	if [[ -z "${bt_device_windows}" ]]; then
		return
	fi
	bt_device_info_keys_reg="$(cat "${tmp_dir}/${tmp_reg}" 2>/dev/null | tr -d '\r' | awk -v ctrl="${bt_controller_windows}" -v dev="${bt_device_windows}" 'tolower($0) ~ tolower("\\[.*Keys\\\\" ctrl "\\\\" dev "\\]") { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }')"
	if [[ "$(echo "${bt_device_info_keys_reg}" | grep -Ei "^(\"IRK\"|\"CSRK\"|\"LTK\"|\"KeyLength\"|\"EDIV\"|\"ERand\")" | wc -l)" -ge '5' ]]; then
		bt_device_type_windows='ble'
	else
		bt_device_type_windows='standard'
	fi
}

function get_bt_keys_linux() {

	if [[ "${bt_device_type_linux}" = 'standard' ]]; then
		key_lk_linux="$(echo "${bt_device_info}" | awk '/^\[LinkKey\]/ { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }' | grep -i '^Key=' | grep -Eo "([[:xdigit:]]){32}$" | tr '[:lower:]' '[:upper:]')"
		if [[ -z "${key_lk_linux}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* linux   LK   key not found. Please try to remove and pair again this device in linux.\e[0m"
		else
			echo "		- linux   LK   key is ${key_lk_linux}"
		fi
	elif [[ "${bt_device_type_linux}" = 'ble' ]]; then
		key_irk_linux="$(echo "${bt_device_info}" | awk "/"\\[IdentityResolvingKey\\]"/,/^$/" | grep '^Key=' | grep -Eo "([[:xdigit:]]){32}$")" # to review
		key_lsk_linux="$(echo "${bt_device_info}" | awk "/"\\[LocalSignatureKey\\]"/,/^$/" | grep '^Key=' | grep -Eo "([[:xdigit:]]){32}$")" # to review
		key_ltk_linux="$(echo "${bt_device_info}" | awk "/"\\[LongTermKey\\]"/,/^$/" | grep '^Key=' | grep -Eo "([[:xdigit:]]){32}$")" # to review
		key_es_linux="$(echo "${bt_device_info}" | awk "/"\\[LongTermKey\\]"/,/^$/" | grep '^EncSize=' | grep -Eo "([[:digit:]])+$")" # to review
		key_ediv_linux="$(echo "${bt_device_info}" | awk "/"\\[LongTermKey\\]"/,/^$/" | grep '^EDiv=' | grep -Eo "([[:digit:]])+$")" # to review
		key_rand_linux="$(echo "${bt_device_info}" | awk "/"\\[LongTermKey\\]"/,/^$/" | grep '^Rand=' | grep -Eo "([[:digit:]])+$")" # to review
		if [[ -z "${key_irk_linux}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* linux   IRK  key not found. Please try to remove and pair again this device in linux.\e[0m"
		else
			echo -e "\e[0;32m		- linux   IRK  key is \e[0;32m${key_irk_linux}\e[0m"
		fi
		if [[ -z "${key_lsk_linux}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* linux   LSK  key not found. Please try to remove and pair again this device in linux.\e[0m"
		else
			echo -e "\e[0;32m		- linux   LSK  key is \e[0;33m${key_lsk_linux}\e[0m"
		fi
		if [[ -z "${key_ltk_linux}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* linux   LTK  key not found. Please try to remove and pair again this device in linux.\e[0m"
		else
			echo -e "\e[0;32m		- linux   LTK  key is \e[1;34m${key_ltk_linux}\e[0m"
		fi
		if [[ -z "${key_es_linux}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* linux   ES   key not found. Please try to remove and pair again this device in linux.\e[0m"
		else
			echo -e "\e[0;32m		- linux   ES   key is \e[1;35m${key_es_linux}\e[0m"
		fi
		if [[ -z "${key_ediv_linux}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* linux   EDIV key not found. Please try to remove and pair again this device in linux.\e[0m"
		else
			echo -e "\e[0;32m		- linux   EDIV key is \e[1;35m${key_ediv_linux}\e[0m"
		fi
		if [[ -z "${key_rand_linux}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* linux   RAND key not found. Please try to remove and pair again this device in linux.\e[0m"
		else
			echo -e "\e[0;32m		- linux   RAND key is \e[1;36m${key_rand_linux}\e[0m"
		fi
	fi
}

function get_bt_keys_windows() {

	if [[ "${bt_device_type_windows}" = 'standard' ]]; then
		key_lk_windows_reg="${bt_device_info_keys_reg}"
		key_lk_windows="$(echo "${key_lk_windows_reg//,/}" | tr '[:lower:]' '[:upper:]')"
		if [[ -z "${key_lk_windows}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* windows LK   key not found. Please try to remove and pair again this device in windows.\e[0m"
		else
			echo "		- windows LK   key is ${key_lk_windows}"
		fi
	elif [[ "${bt_device_type_windows}" = 'ble' ]]; then
		key_irk_windows_reg="$(echo "${bt_device_info_keys_reg}" | grep '^"IRK"' | grep -Eo "([[:xdigit:]]{1,2},){15}[[:xdigit:]]{2}$")" # to review
		key_irk_windows="$(echo "${key_irk_windows_reg//,/}" | tr '[:lower:]' '[:upper:]')" # to review

		key_lsk_windows_reg="$(echo "${bt_device_info_keys_reg}" | grep '^"CSRK"' | grep -Eo "([[:xdigit:]]{1,2},){15}[[:xdigit:]]{2}$")" # to review
		key_lsk_windows="$(echo "${key_lsk_windows_reg//,/}" | tr '[:lower:]' '[:upper:]')" # to review

		key_ltk_windows_reg="$(echo "${bt_device_info_keys_reg}" | grep '^"LTK"' | grep -Eo "([[:xdigit:]]{1,2},){15}[[:xdigit:]]{2}$")" # to review
		key_ltk_windows="$(echo "${key_ltk_windows_reg//,/}" | tr '[:lower:]' '[:upper:]')" # to review

		key_es_windows_reg="$(echo "${bt_device_info_keys_reg}" | grep '^"KeyLength"' | awk -F':' '{print $2}')" # to review
		key_es_windows="$(echo "obase=10; ibase=16; ${key_es_windows_reg}" | bc)" # to review

		key_ediv_windows_reg="$(echo "${bt_device_info_keys_reg}" | grep '^"EDIV"' | awk -F':' '{print $2}')" # to review
		key_ediv_windows="$(echo "obase=10; ibase=16; ${key_ediv_windows_reg}" | bc)" # to review

		key_rand_windows_reg="$(echo "${bt_device_info_keys_reg}" | grep '^"ERand"' | awk -F':' '{print $2}')" # to review
		key_rand_windows="$(echo "${key_rand_windows_reg}" | awk -F',' '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }' | tr '[:lower:]' '[:upper:]')" # to review
		key_rand_windows="$(echo "obase=10; ibase=16; ${key_rand_windows// /}" | bc)" # to review

		if [[ -z "${key_irk_windows}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* windows IRK  key not found. Please try to remove and pair again this device in windows.\e[0m"
		else
			echo -e "\e[0;32m		- windows IRK  key is \e[0;32m${key_irk_windows}\e[0m"
		fi
		if [[ -z "${key_lsk_windows}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* windows LSK  key not found. Please try to remove and pair again this device in windows.\e[0m"
		else
			echo -e "\e[0;32m		- windows LSK  key is \e[0;33m${key_lsk_windows}\e[0m"
		fi
		if [[ -z "${key_ltk_windows}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* windows LTK  key not found. Please try to remove and pair again this device in windows.\e[0m"
		else
			echo -e "\e[0;32m		- windows LTK  key is \e[1;34m${key_ltk_windows}\e[0m"
		fi
		if [[ -z "${key_es_windows}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* windows ES   key not found. Please try to remove and pair again this device in windows.\e[0m"
		else
			echo -e "\e[0;32m		- windows ES   key is \e[1;35m${key_es_windows}\e[0m"
		fi
		if [[ -z "${key_ediv_windows}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* windows EDIV key not found. Please try to remove and pair again this device in windows.\e[0m"
		else
			echo -e "\e[0;32m		- windows EDIV key is \e[1;35m${key_ediv_windows}\e[0m"
		fi
		if [[ -z "${key_rand_windows}" ]]; then
			nokey='1'
			echo -e "\e[1;31m		* windows RAND key not found. Please try to remove and pair again this device in windows.\e[0m"
		else
			echo -e "\e[0;32m		- windows RAND key is \e[1;36m${key_rand_windows}\e[0m"
		fi
	fi
}

function compare_bt_keys() {

	unset different
	if [[ "${bt_device_type}" = 'standard' ]]; then
		if [[ "${key_lk_linux^^}" != "${key_lk_windows^^}" ]]; then
			different='true'
		fi
	elif [[ "${bt_device_type}" = 'ble' ]]; then
		if [[ "${key_irk_linux}" != "${key_irk_windows}" ]]; then
			different='true'
		fi
		if [[ "${key_lsk_linux}" != "${key_lsk_windows}" ]]; then
			different='true'
		fi
		if [[ "${key_ltk_linux}" != "${key_ltk_windows}" ]]; then
			different='true'
		fi
		if [[ "${key_es_linux}" != "${key_es_windows}" ]]; then
			different='true'
		fi
		if [[ "${key_ediv_linux}" != "${key_ediv_windows}" ]]; then
			different='true'
		fi
		if [[ "${key_rand_linux}" != "${key_rand_windows}" ]]; then
			different='true'
		fi
	fi
}

function bt_keys_sync_common() {

	unset bt_keys_sync_from_os
	retry='0'
	while true; do
		if [[ "${only_list}" = 'true' ]] || [[ "${skip}" = 'true' ]] || [[ "${retry}" -eq '10' ]]; then
			bt_devices_not_synced+="- bluetooth controller: ${bt_controller_macaddr} \ bluetooth device: ${bt_device_macaddr} - ${bt_device_name}\n"
			if [[ "${only_list}" = 'true' ]] || [[ "${skip}" = 'true' ]]; then
				echo -e "\e[1;33m		* skipping this device\e[0m"
				unset skip
			elif [[ "${retry}" -eq '10' ]]; then
				echo -e "\e[1;31m		* error while updating the key!\e[0m"
			fi
			break
		fi
		if [[ "${different}" = 'true' ]]; then
			if [[ "${keys_ask}" = 'true' ]]; then
				bt_keys_sync_ask
				retry='0'
			elif [[ "${keys_from}" = 'linux' ]]; then
				bt_keys_sync_from_linux
			elif [[ "${keys_from}" = 'windows' ]]; then
				bt_keys_sync_from_windows
			fi
			compare_bt_keys
		fi
		if [[ "${different}" != 'true' ]]; then
			echo -e "\e[1;32m		* keys are synced\e[0m"
			noerror='1'
			if [[ "${bt_keys_sync_from_os}" = 'windows' ]]; then
				# Stop bluetooth before writing key files so bluetoothd releases its file locks
				echo -e "\e[1;33m		* stopping bluetooth service before writing keys...\e[0m"
				check_sudo
				sudo systemctl stop bluetooth
				bluetooth_stopped='1'
				sleep 1
				sudo cp "${tmp_dir}/${tmp_info_new}" "/var/lib/bluetooth/${bt_controller_linux}/${bt_device_linux}/info"
				sudo chmod 600 "/var/lib/bluetooth/${bt_controller_linux}/${bt_device_linux}/info"
				if command -v restorecon >/dev/null 2>&1; then
					sudo restorecon "/var/lib/bluetooth/${bt_controller_linux}/${bt_device_linux}/info"
				fi
				bt_devices_sync_from_windows+="- bluetooth controller: ${bt_controller_macaddr} \ bluetooth device: ${bt_device_macaddr} - ${bt_device_name}\n"
			elif [[ "${bt_keys_sync_from_os}" = 'linux' ]]; then
				check_sudo
				sudo cp "${tmp_dir}/${tmp_reg_new}" "${tmp_dir}/${tmp_reg}"
				bt_devices_sync_from_linux+="- bluetooth controller: ${bt_controller_macaddr} \ bluetooth device: ${bt_device_macaddr} - ${bt_device_name}\n"
			fi
			break
		fi
		retry="$(("${retry}" + 1))"
	done
}

function bt_keys_sync_ask() {

	while true; do
		echo -e "\e[1;32m		- which pairing key you want to use? (the os in wich you last paired this device has the newer working key)\e[0m"
		echo -e "\e[1;31m		- 0) skip	1) linux key	2) windows key\e[0m"

		unset selected_key
		read -rp "		* choose> " selected_key

		if [[ ! "${selected_key}" =~ ^[[:digit:]]+$ ]] || [[ "${selected_key}" -gt '3' ]] || [[ "${selected_key}" -lt '0' ]]; then
			echo -e "\e[1;31m		Invalid choice!\e[0m"
				sleep '1'
		elif [[ "${selected_key}" -eq '0' ]]; then
			skip='true'
			break
		elif [[ "${selected_key}" -eq '1' ]]; then
			if [[ "${system_hive_permission}" = 'rw' ]]; then
				bt_keys_sync_from_linux
				break
			else
				echo
				echo -e "\e[1;31m		* ${system_hive}: you don't have write permission\e[0m"
				echo -e "\e[1;31m		* you will only be able to import bluetooth pairing keys from windows to linux, not the opposite\e[0m"
				echo -e "\e[1;31m		* make sure you have read\write access\e[0m"
				echo
				sleep '1'
			fi
		elif [[ "${selected_key}" -eq '2' ]]; then
			bt_keys_sync_from_windows
			break
		fi
	done
}

function bt_keys_sync_from_windows() {

	echo -e "\e[1;33m		* updating linux key...\e[0m"
	bt_keys_sync_from_os='windows'
	check_sudo
	sudo cp "/var/lib/bluetooth/${bt_controller_linux}/${bt_device_linux}/info" "${tmp_dir}/${tmp_info_new}"
	if [[ "${bt_device_type}" = 'standard' ]]; then
		# Replace key only in [LinkKey] section
		check_sudo
		sudo awk -v newkey="${key_lk_windows^^}" '
			/^\[LinkKey\]/ { in_linkkey=1 }
			/^\[/ && !/^\[LinkKey\]/ { in_linkkey=0 }
			in_linkkey && /^Key=/ { $0 = "Key=" newkey }
			{ print }
		' "${tmp_dir}/${tmp_info_new}" | sudo tee "${tmp_dir}/${tmp_info_new}.tmp" >/dev/null && sudo mv "${tmp_dir}/${tmp_info_new}.tmp" "${tmp_dir}/${tmp_info_new}"
	elif [[ "${bt_device_type}" = 'ble' ]]; then
		if [[ "${key_irk_linux}" != "${key_irk_windows}" ]]; then
			check_sudo
			sudo sed -i "s/Key=${key_irk_linux}/Key=${key_irk_windows}/g" "${tmp_dir}/${tmp_info_new}"
		fi
		if [[ "${key_lsk_linux}" != "${key_lsk_windows}" ]]; then
			check_sudo
			sudo sed -i "s/Key=${key_lsk_linux}/Key=${key_lsk_windows}/g" "${tmp_dir}/${tmp_info_new}"
		fi
		if [[ "${key_ltk_linux}" != "${key_ltk_windows}" ]]; then
			check_sudo
			sudo sed -i "s/Key=${key_ltk_linux}/Key=${key_ltk_windows}/g" "${tmp_dir}/${tmp_info_new}"
		fi
		if [[ "${key_es_linux}" != "${key_es_windows}" ]]; then
			check_sudo
			sudo sed -i "s/EncSize=${key_es_linux}/EncSize=${key_es_windows}/g" "${tmp_dir}/${tmp_info_new}"
		fi
		if [[ "${key_ediv_linux}" != "${key_ediv_windows}" ]]; then
			check_sudo
			sudo sed -i "s/EDiv=${key_ediv_linux}/EDiv=${key_ediv_windows}/g" "${tmp_dir}/${tmp_info_new}"
		fi
		if [[ "${key_rand_linux}" != "${key_rand_windows}" ]]; then
			check_sudo
			sudo sed -i "s/Rand=${key_rand_linux}/Rand=${key_rand_windows}/g" "${tmp_dir}/${tmp_info_new}"
		fi
	fi
	check_sudo
	bt_device_info="$(sudo cat "${tmp_dir}/${tmp_info_new}" 2>/dev/null)"
	get_bt_keys_linux
}

function bt_keys_sync_from_linux() {

	echo -e "\e[1;33m		* updating windows registry key...\e[0m"
	bt_keys_sync_from_os='linux'
	bt_device_info_keys_reg="$(cat "${tmp_dir}/${tmp_reg}" 2>/dev/null | tr -d '\r' | awk -v ctrl="${bt_controller_windows}" 'tolower($0) ~ tolower("\\[.*Keys\\\\" ctrl "\\]") { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }')"
	cp "${tmp_dir}/${tmp_reg}" "${tmp_dir}/${tmp_reg_new}"
	if [[ "${bt_device_type}" = 'standard' ]]; then
		key_lk_linux_reg="$(echo "${key_lk_linux,,}" | sed 's/.\{2\}/&,/g' | sed 's/.$//')"
		check_sudo
		sudo sed -i -E "s/\"${bt_device_windows}\"=hex:[0-9a-fA-F,]+/\"${bt_device_windows}\"=hex:${key_lk_linux_reg}/I" "${tmp_dir}/${tmp_reg_new}"
	elif [[ "${bt_device_type}" = 'ble' ]]; then
		if [[ "${key_irk_linux}" != "${key_irk_windows}" ]]; then
			key_irk_linux_reg="$(echo "${key_irk_linux,,}" | sed 's/.\{2\}/&,/g' | sed 's/.$//')" # to review
			check_sudo
			sudo sed -i "s/\"IRK\"=hex:${key_irk_windows_reg}/\"IRK\"=hex:${key_irk_linux_reg}/g" "${tmp_dir}/${tmp_reg_new}"
		fi
		if [[ "${key_lsk_linux}" != "${key_lsk_windows}" ]]; then
			key_lsk_linux_reg="$(echo "${key_lsk_linux,,}" | sed 's/.\{2\}/&,/g' | sed 's/.$//')" # to review
			check_sudo
			sudo sed -i "s/\"CSRK\"=hex:${key_lsk_windows_reg}/\"CSRK\"=hex:${key_lsk_linux_reg}/g" "${tmp_dir}/${tmp_reg_new}"
		fi
		if [[ "${key_ltk_linux}" != "${key_ltk_windows}" ]]; then
			key_ltk_linux_reg="$(echo "${key_ltk_linux,,}" | sed 's/.\{2\}/&,/g' | sed 's/.$//')" # to review
			check_sudo
			sudo sed -i "s/\"LTK\"=hex:${key_ltk_windows_reg}/\"LTK\"=hex:${key_ltk_linux_reg}/g" "${tmp_dir}/${tmp_reg_new}"
		fi
		if [[ "${key_es_linux}" != "${key_es_windows}" ]]; then
			key_es_linux_reg="$(printf '%x\n' "${key_es_linux}")" # to review
			until [[ "$(echo "${key_es_linux_reg}" | wc -m)" = '8' ]]; do
				key_es_linux_reg="0${key_es_linux_reg}"
			done
			check_sudo
			sudo sed -i "s/\"KeyLength\"=dword:${key_es_linux_reg}/\"KeyLength\"=dword:${key_es_linux_reg}/g" "${tmp_dir}/${tmp_reg_new}"
		fi
		if [[ "${key_ediv_linux}" != "${key_ediv_windows}" ]]; then
			key_ediv_linux_reg="$(printf '%x\n' "${key_ediv_linux}")" # to review
			until [[ "$(echo "${key_ediv_linux_reg}" | wc -m)" = '8' ]]; do
				key_ediv_linux_reg="0${key_ediv_linux_reg}"
			done
			check_sudo
			sudo sed -i "s/\"EDIV\"=dword:${key_ediv_windows_reg}/\"EDIV\"=dword:${key_ediv_linux_reg}/g" "${tmp_dir}/${tmp_reg_new}"
		fi
		if [[ "${key_rand_linux}" != "${key_rand_windows}" ]]; then
			key_rand_linux_hex="$(printf '%x\n' "${key_rand_linux}" | sed 's/.\{2\}/&,/g')" # to review
			key_rand_linux_reverse="$(echo "${key_rand_linux_hex::-1}" | awk -F',' '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }')" # to review
			key_rand_linux_reg="${key_rand_linux_reverse//' '/$','}" # to review
			check_sudo
			sudo sed -i "s/\"ERand\"=hex(b):${key_rand_windows_reg}/\"ERand\"=hex(b):${key_rand_linux_reg}/g" "${tmp_dir}/${tmp_reg_new}"
		fi
	fi
	if [[ "${bt_device_type_windows}" = 'standard' ]]; then
		bt_device_info_keys_reg="$(cat "${tmp_dir}/${tmp_reg_new}" 2>/dev/null | tr -d '\r' | awk -v ctrl="${bt_controller_windows}" 'tolower($0) ~ tolower("\\[.*Keys\\\\" ctrl "\\]") { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }' | grep -Fi "\"${bt_device_windows}\"=hex:" | grep -Eo "([[:xdigit:]]{1,2},){15}[[:xdigit:]]{2}$")"
	elif [[ "${bt_device_type_windows}" = 'ble' ]]; then
		bt_device_info_keys_reg="$(cat "${tmp_dir}/${tmp_reg_new}" 2>/dev/null | tr -d '\r' | awk -v ctrl="${bt_controller_windows}" -v dev="${bt_device_windows}" 'tolower($0) ~ tolower("\\[.*Keys\\\\" ctrl "\\\\" dev "\\]") { in_sec=1; next } in_sec && /^\[/ { in_sec=0 } in_sec { print }')"
	fi
	get_bt_keys_windows
}

function bt_keys_sync() {

	if ! command -v reged >/dev/null 2>&1; then
		echo -e "\e[1;31mERROR: This script require \e[1;34mchntpw\e[1;31m. Install it with: \e[1;34msudo dnf install chntpw\e[1;31m (Fedora) or \e[1;34msudo apt install chntpw\e[1;31m (Debian/Ubuntu)\e[0m"
		skip_pause='true'
		exit 1
	fi

	check_sudo
	if ! [[ -f "${tmp_dir}/${tmp_hive}" ]] || ! sudo cmp -s "${system_hive}" "${tmp_dir}/${tmp_hive}"; then
		if ! sudo cp "${system_hive}" "${tmp_dir}/${tmp_hive}"; then
			echo -e "\e[1;31m* error while copying windows SYSTEM registry hive to ${tmp_dir}/${tmp_hive}\e[0m"
			skip_pause='true'
			exit 1
		fi
		sudo chmod 600 "${tmp_dir}/${tmp_hive}"
	fi

	check_sudo
	if sudo reged -x "${tmp_dir}/${tmp_hive}" "HKEY_LOCAL_MACHINE\SYSTEM" "\\${control_set}\Services\BTHPORT\Parameters\Keys" "${tmp_dir}/${tmp_reg}"; then
		sudo chmod 644 "${tmp_dir}/${tmp_reg}" 2>/dev/null || true
		if [[ -f "${tmp_dir}/${tmp_reg}" ]] && grep -Fiq "HKEY_LOCAL_MACHINE\SYSTEM\\${control_set}\Services\BTHPORT\Parameters\Keys" "${tmp_dir}/${tmp_reg}"; then
			check_bt_controllers
			if [[ -z "${bt_devices_not_synced}" ]] && [[ "${noerror}" = '1' ]] && [[ -z "${bt_devices_sync_from_linux}" ]] && [[ -z "${bt_devices_sync_from_windows}" ]]; then
				if [[ "${nokey_warn}" = '1' ]]; then
					color='1;33'
				else
					color='1;32'
				fi
				echo
				echo -e "\e[${color}m----------------------------------------------------------------------\e[0m"
				echo -e "\e[${color}m                            Nothing to do.\e[0m"
				echo -e "\e[${color}m----------------------------------------------------------------------\e[0m"
			else
				if [[ "${noerror}" != '1' ]]; then
					echo
					echo -e "\e[1;33m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;33m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;33mPlease make sure the bluetooth devices are paired in both linux and windows!\e[0m"
					echo -e "\e[1;33m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;33m----------------------------------------------------------------------\e[0m"
				fi
				if [[ -n "${bt_devices_not_synced}" ]]; then
					echo
					echo -e "\e[1;33m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;33m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;33mThe bluetooth pairing keys from the following devices are not synced:\e[0m"
					echo -e "${bt_devices_not_synced}"
					echo -e "\e[1;33m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;33m----------------------------------------------------------------------\e[0m"
				fi
				if [[ -n "${bt_devices_sync_from_windows}" ]]; then
					echo
					echo -e "\e[1;32m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;32m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;32m- The windows bluetooth pairing keys from the following devices have been imported to linux:\e[0m"
					echo -e "${bt_devices_sync_from_windows}"
					echo -e "\e[1;32m- The os in wich you last paired these devices has the newer working keys\e[0m"
					echo -e "\e[1;32m  so make sure that windows is the last os in which you paired these bluetooth devices!\e[0m"
					echo -e "\e[1;32m- If not, boot into windows and pair them there (if yet paired, remove them first) so windows has the newer working keys\e[0m"
					echo -e "\e[1;32m  then boot into linux and run ${bt_keys_sync_name} again.\e[0m"
					echo
					echo -e "\e[1;32m- restarting bluetooth service...\e[0m"
					check_sudo
					sudo systemctl start bluetooth
					unset bluetooth_stopped
					echo -e "\e[1;32m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;32m-------------------------------- done --------------------------------\e[0m"
					echo -e "\e[1;32m----------------------------------------------------------------------\e[0m"
				fi

				if [[ -n "${bt_devices_sync_from_linux}" ]]; then
					echo
					echo -e "\e[1;31m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;31m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;31m- The linux bluetooth pairing keys from the following devices haven't yet been imported to the windows SYSTEM registry hive:\e[0m"
					echo -e "${bt_devices_sync_from_linux}"
					echo -e "\e[1;31m- This procedure is risky as it could mess with the windows registry.\e[0m"
					echo -e "\e[1;31m  The os in wich you last paired these devices has the newer working keys\e[0m"
					echo -e "\e[1;31m  so the recommended procedure is to boot into windows and pair them there (if yet paired, remove them first) so windows has the newer working keys\e[0m"
					echo -e "\e[1;31m  then boot into linux, run ${bt_keys_sync_name} and always choose \"windows key\" when prompted \"which pairing key you want to use?\" (or use option --windows-keys).\e[0m"
					echo
					echo -e "\e[1;31m- If you, at your own risk, decide to import the bluetooth pairing keys from linux to windows (this has been tested on windows 10 and 11)\e[0m"
					echo -e "\e[1;31m  proceed with caution as this modifies the windows registry directly.\e[0m"

					if [[ -f "${system_hive%/*}/SOFTWARE" ]] || sudo test -f "${system_hive%/*}/SOFTWARE"; then
						check_sudo
						sudo reged -x "${system_hive%/*}/SOFTWARE" "HKEY_LOCAL_MACHINE\SOFTWARE" "Microsoft\Windows NT\CurrentVersion" "${tmp_dir}/${tmp_ver}" >/dev/null 2>&1
						win_version="$(grep -Fi '"ProductName"' "${tmp_dir}/${tmp_ver}" 2>/dev/null | cut -d'=' -f2- | tr -d '"\r')"
						if [[ -n "${win_version}" ]]; then
							echo
							echo -e "\e[1;31m* Your windows version seems to be: ${win_version}\e[0m"
						else
							echo
							echo -e "\e[1;31m* Unable to retrieve windows version!\e[0m"
						fi
					else
						echo
						echo -e "\e[1;31m* Unable to retrieve windows version!\e[0m"
					fi

					while true; do
						echo
						echo -e "\e[1;31m- do you want to import the linux bluetooth pairing keys to the windows SYSTEM registry hive?\e[0m"
						echo -e "\e[1;32m0) No\e[0m"
						echo -e "\e[1;31m1) Yes\e[0m"
						read -rp " choose> " import_registry
						if [[ ! "${import_registry}" =~ ^[[:digit:]]+$ ]] || [[ "${import_registry}" -gt '1' ]] || [[ "${import_registry}" -lt 0 ]]; then
							echo -e "\e[1;31mInvalid choice!\e[0m"
							sleep '1'
						elif [[ "${import_registry}" -eq '0' ]]; then
							echo -e "\e[1;33mwindows SYSTEM registry hive left untouched.\e[0m"
							echo -e "\e[1;33mwindows bluetooth pairing keys haven't been updated.\e[0m"
							exit 0
						elif [[ "${import_registry}" -eq '1' ]]; then
							echo
							echo -e "\e[1;31m- importing the linux bluetooth pairing keys to the windows SYSTEM registry hive...\e[0m"
							check_sudo
							sudo reged -ICN "${tmp_dir}/${tmp_hive}" "HKEY_LOCAL_MACHINE\SYSTEM" "${tmp_dir}/${tmp_reg}"
							echo -e "\e[1;33m- creating backup ${system_hive}.bak...\e[0m"
							sudo cp -a "${system_hive}" "${system_hive}.bak"
							if sudo cp "${tmp_dir}/${tmp_hive}" "${system_hive}"; then
								break
							else
								echo -e "\e[1;31m- error while importing the linux bluetooth pairing keys to the windows SYSTEM registry hive\e[0m"
								skip_pause='true'
								exit 1
							fi
						fi
					done
					echo -e "\e[1;31m----------------------------------------------------------------------\e[0m"
					echo -e "\e[1;31m-------------------------------- done --------------------------------\e[0m"
					echo -e "\e[1;31m----------------------------------------------------------------------\e[0m"
				fi
			fi
		else
			echo -e "\e[1;31m* ${system_hive}: error while exporting windows SYSTEM registry hive to ${tmp_dir}/${tmp_reg}\e[0m"
			error='1'
		fi
	else
		echo -e "\e[1;31m* ${system_hive}: error while exporting windows SYSTEM registry hive to ${tmp_dir}/${tmp_reg}\e[0m"
		error='1'
	fi
}

function check_sudo() {

	if [[ "${EUID}" -eq 0 ]]; then
		sudouser='1'
		return 0
	fi

	if [[ "${sudouser}" != '1' ]]; then
		current_sudo="$(date +%s)"
		if [[ -z "${last_sudo}" ]] || (( current_sudo - last_sudo >= 240 )); then
			while true; do
				echo -e "\e[1;33mIn order to proceed you must grant root permissions\e[0m"
				if sudo -v; then
					last_sudo="$(date +%s)"
					break
				else
					echo -e "\e[1;31mPermission denied! Press ENTER to exit or wait 5 seconds to retry\e[0m"
					if read -t 5 _e; then
						force_exit='1'
						skip_pause='true'
						exit 1
					fi
				fi
			done
		fi
	fi
}

function find_system_hive() {

	local -a found_hives=()
	for search_path in '/media/' '/mnt/' '/run/media/' '/run/'; do
		[[ -d "${search_path}" ]] || continue
		echo -e "\e[1;32m* searching in ${search_path} ...\e[0m"
		while IFS= read -r f; do
			[[ -n "${f}" ]] && found_hives+=("${f}")
		done < <(find "${search_path}" -maxdepth 9 -type f -ipath '*/Windows/System32/config/SYSTEM' 2>/dev/null)
		if [[ ${#found_hives[@]} -eq 0 ]] && sudo -n true 2>/dev/null; then
			while IFS= read -r f; do
				[[ -n "${f}" ]] && found_hives+=("${f}")
			done < <(sudo -n find "${search_path}" -maxdepth 9 -type f -ipath '*/Windows/System32/config/SYSTEM' 2>/dev/null)
		fi
	done

	# Deduplicate found hives
	if [[ ${#found_hives[@]} -gt 1 ]]; then
		mapfile -t found_hives < <(printf "%s\n" "${found_hives[@]}" | sort -u)
	fi

	while true; do
		echo
		if [[ ${#found_hives[@]} -eq 0 ]]; then
			echo -e "\e[1;31m- no results while searching for a windows SYSTEM registry hive file\e[0m"
			local unmounted_ntfs
			unmounted_ntfs="$(lsblk -rn -o NAME,FSTYPE,LABEL,MOUNTPOINTS 2>/dev/null | awk '$2 == "ntfs" && $4 == "" {print $1 ($3 ? " (" $3 ")" : "")}')"
			if [[ -n "${unmounted_ntfs}" ]]; then
				echo -e "\e[1;33m* detected unmounted Windows/NTFS partition(s): ${unmounted_ntfs}\e[0m"
				echo -e "\e[1;33m* please mount your Windows partition (e.g. open it in Dolphin or file manager) and try again.\e[0m"
				echo
			fi
			while true; do
				echo -e "\e[1;32m* please enter the full path of the windows SYSTEM registry hive file:\e[0m"
				echo ' 0) Exit'
				read -rp " > " system_hive
				if echo "${system_hive}" | grep -Eixq "(exit|e|quit|q|0)"; then
					skip_pause='true'
					exit 0
				else
					if [[ -f "${system_hive}" ]] || sudo -n test -f "${system_hive}" 2>/dev/null; then
						break 2
					else
						echo -e "\e[1;31m* ${system_hive}: file not found\e[0m"
						echo
						sleep '2'
					fi
				fi
			done
		else
			echo -e "\e[1;32m* please select a windows SYSTEM registry hive file:\e[0m"
			echo ' 0) Exit'
			local i=0
			for path in "${found_hives[@]}"; do
				i=$((i + 1))
				local sp1=' '
				if [[ "${i}" -gt 9 ]]; then
					unset sp1
				fi
				echo -e "${sp1}${i}) ${path}"
			done
			unset selected_path
			echo
			read -rp " choose> " selected_path
			if [[ ! "${selected_path}" =~ ^[[:digit:]]+$ ]] || [[ "${selected_path}" -gt "${i}" ]] || [[ "${selected_path}" -lt 0 ]]; then
				echo
				echo -e "\e[1;31mInvalid choice!\e[0m"
				sleep '1'
			elif [[ "${selected_path}" -eq 0 ]]; then
				skip_pause='true'
				exit 0
			else
				system_hive="${found_hives[$((selected_path - 1))]}"
				break
			fi
		fi
	done
}

function cleaning() {
	local exit_code=$?

	if [[ "${bluetooth_stopped}" = '1' ]]; then
		echo -e "\e[1;32m- restarting bluetooth service...\e[0m"
		sudo systemctl start bluetooth >/dev/null 2>&1
	fi

	if [[ "${force_exit}" != '1' && -n "${tmp_dir}" && -d "${tmp_dir}" ]]; then
		rm -rf "${tmp_dir}" 2>/dev/null || sudo rm -rf "${tmp_dir}" 2>/dev/null
	fi

	if [[ "${create_menu}" = 'true' ]] && [[ "${EUID}" != '0' ]]; then
		local desktop_file="$HOME/.local/share/applications/bt-keys-sync.desktop"
		if ! grep -Eqs "^Exec=${bt_keys_sync_name}$" "${desktop_file}" 2>/dev/null; then
			mkdir -p "$HOME/.local/share/applications"
			cat > "${desktop_file}" <<-DESKTOP
			[Desktop Entry]
			Name=bt-keys-sync
			Exec=${bt_keys_sync_name}
			Icon=bluetooth
			Terminal=true
			Type=Application
			StartupNotify=false
			Categories=AudioVideo;Audio;Utility;
			DESKTOP
		fi
	fi

	if [[ "${skip_pause}" != 'true' && -t 0 && "${exit_code}" -eq 0 ]]; then
		echo
		echo -e "\e[1;32mPress ENTER to exit\e[0m"
		read -sr _e
	fi

	exit "${exit_code}"
}

function check_keys_from()	{

	if [[ -n "${keys_from}" ]]; then
		echo -e "\e[1;31m* ERROR: only one option is permitted between --linux-keys and --windows-keys\e[0m"
		givemehelp
		exit 1
	else
		keys_from="${keys_from_check}"
		unset keys_ask
	fi
}

function givemehelp() {
	skip_pause='true'

	echo "
# bt-keys-sync

# Version:    2.0.0
# Author:     nightcodex7
# Github:     https://github.com/nightcodex7
# Repository: https://github.com/nightcodex7/bt-keys-sync-fedora
# License:    GNU General Public License v3.0, https://opensource.org/licenses/GPL-3.0

### DESCRIPTION
When pairing a bluetooth device to a bluetooth controller, a random key is generated in order to authenticate the connection, so e.g. in a multi boot scenario, only the os in wich you last paired this device has the newer working key, you'll need to pair it again in another system (then only this other system will have the newer working key).
This is true for every system, whether they are linux or windows or both or wathever.

This script is intended to be used in a linux\windows multi boot scenario (optimised for Fedora KDE 44+). It will check for linux and windows paired bluetooth devices and, if it finds that a device pairing key isn't equal between linux\windows, it will ask which pairing key you want to use (the os in wich you last paired this device has the newer working key) so it will update the old key with the new key accordingly.

Importing the bluetooth pairing keys from windows to linux is a safe procedure. Before writing the new key files, the bluetooth service is automatically stopped and restarted afterward to ensure changes take effect cleanly.
This could not be true for the opposite, importing the bluetooth pairing keys from linux to windows is risky as it could mess with the windows registry, so the recommended procedure is to pair your bluetooth devices in linux, then boot into windows and pair them there (if yet paired, remove them first) so windows has the newer working keys, then boot into linux and run ${bt_keys_sync_name} and always choose \"windows key\" when prompted \"which pairing key you want to use?\" (or use option --windows-keys).
If you, at your own risk, decide to import the bluetooth pairing keys from linux to windows (this has been tested on windows 10 and 11) proceed with caution as this modifies the windows registry directly.

### About Bluetooth Low Energy (BLE)
Bluetooth Low Energy Device (BLE) can be detected, but key checks will be skipped.
Please take a look here: https://github.com/nightcodex7/bt-keys-sync-fedora/issues

This script require \"chntpw\". Install it with:
sudo dnf install chntpw    # Fedora
sudo apt install chntpw    # Debian/Ubuntu

### USAGE
Mount the windows partition (make sure you have read\write access to it), then run this script:
$ ${bt_keys_sync_name}

It will search for a windows SYSTEM registry hive file in /media, /mnt and /run.
If no windows SYSTEM registry hive file is found, then you must enter the full path (usually is something like \"<windows_mount_point>/Windows/System32/config/SYSTEM\").

You can skip the automatic search by the option --path.

With the --control-set option you can change the control set to check. Default is ControlSet001.

Options:
-p, --path <system_hive_path>    Enter the full path of the windows SYSTEM registry hive file.
-c, --control-set <control_set>  Enter the control set to check. Default is 'ControlSet001'.
-l, --linux-keys                 Import bluetooth pairing keys from linux to windows without asking.
-w, --windows-keys               Import bluetooth pairing keys from windows to linux without asking.
-o, --only-list                  Only list bluetooth devices and pairing keys, don't do anything else.
-h, --help                       Show this help.
"
}

bt_keys_sync_name="$(echo "${0}" | rev | awk -F'/' '{print $1}' | rev)"
if ! command -v "${bt_keys_sync_name}" > /dev/null; then
	bt_keys_sync_name="$(readlink -f "${0}")"
fi
export bt_keys_sync_name

printf "\033]2;${bt_keys_sync_name}\a"

myuser="${SUDO_USER:-${USER}}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bt-keys-sync.XXXXXX")"
tmp_reg='bt_reg_keys.reg'
tmp_reg_new='bt_reg_keys_new.reg'
tmp_devs='bt_reg_devs.reg'
tmp_ver='bt_reg_ver.reg'
tmp_hive='SYSTEM_hive_win'
tmp_info_new='bt_info_keys_new'
control_set='ControlSet001'
keys_ask='true'

trap cleaning EXIT

for opt in "$@"; do
	shift
	case "$opt" in
		'--path')			set -- "$@" '-p' ;;
		'--control-set')	set -- "$@" '-c' ;;
		'--linux-keys')		set -- "$@" '-l' ;;
		'--windows-keys')	set -- "$@" '-w' ;;
		'--only-list')	    set -- "$@" '-o' ;;
		'--help')			set -- "$@" '-h' ;;
		*)					set -- "$@" "$opt"
	esac
done

while getopts "p:c:lwoh" opt; do
	case ${opt} in
		p ) system_hive="${OPTARG}"
		;;
		c ) control_set="${OPTARG}"
		;;
		l ) keys_from_check='linux'; check_keys_from
		;;
		w ) keys_from_check='windows'; check_keys_from
		;;
		o ) only_list='true'
		;;
		h ) givemehelp; exit 0
		;;
		*) givemehelp; exit 1
		;;
	esac
done

echo
echo '# bt-keys-sync'
echo

if [[ -z "${system_hive}" ]] || ! { [[ -f "${system_hive}" ]] || sudo -n test -f "${system_hive}" 2>/dev/null; }; then
	find_system_hive
fi

check_sudo

if [[ -f "${system_hive}" ]] || sudo test -f "${system_hive}"; then
	if [[ -r "${system_hive}" ]] || sudo test -r "${system_hive}"; then
		system_hive_permission='r'
	else
		echo -e "\e[1;31m* ${system_hive}: you don't have read permission\e[0m"
		skip_pause='true'
		exit 1
	fi
	if [[ -w "${system_hive}" ]] || sudo test -w "${system_hive}"; then
		system_hive_permission+="w"
	else
		echo -e "\e[1;31m* ${system_hive}: you don't have write permission\e[0m"
		echo -e "\e[1;31m* you will only be able to import bluetooth pairing keys from windows to linux, not the opposite\e[0m"
		if [[ "${keys_from}" = 'linux' ]]; then
			echo -e "\e[1;31m* make sure you have read\write access\e[0m"
			skip_pause='true'
			exit 1
		fi
	fi
	bt_keys_sync
	create_menu='true'
else
	echo -e "\e[1;31m* ${system_hive}: file not found\e[0m"
	error='1'
fi

if [[ "${error}" = '1' ]]; then
	echo -e "\e[1;31m* make sure you enter a valid windows SYSTEM registry hive file path\e[0m"
	if [[ "${control_set}" != 'ControlSet001' ]]; then
		echo -e "\e[1;31m* make sure you enter a valid control set\e[0m"
	fi
	skip_pause='true'
	givemehelp
	exit 1
fi

exit 0
