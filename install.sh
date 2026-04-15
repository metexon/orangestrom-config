#!/bin/sh

set -e

KLIPPER_SERVICE="klipper"
PRINTER_CONFIG_PATH="${HOME}/printer_data/config"
KLIPPER_STOPPED=0


report_status() {
    echo
    echo "###### $1"
    echo
}


resolve_script_dir() {
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
    MOONRAKER_UPDATE_FILE="${SCRIPT_DIR}/moonraker-update-section.conf"
}


check_required_files() {
    required_file=""

    for required_file in \
        "${SCRIPT_DIR}/printer.cfg" \
        "${SCRIPT_DIR}/printer_mcu.cfg" \
        "${SCRIPT_DIR}/printer_mcu1.cfg" \
        "${MOONRAKER_UPDATE_FILE}"; do
        if [ ! -f "${required_file}" ]; then
            echo "Required file not found: ${required_file}"
            exit 1
        fi
    done
}


ensure_printer_config_path() {
    mkdir -p "${PRINTER_CONFIG_PATH}"
}


backup_existing_path() {
    target_path="$1"
    backup_path=""

    if [ ! -e "${target_path}" ] && [ ! -L "${target_path}" ]; then
        return
    fi

    backup_path="${target_path}.bak"

    if [ -e "${backup_path}" ] || [ -L "${backup_path}" ]; then
        backup_path="${target_path}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    mv "${target_path}" "${backup_path}"
    echo "Backed up $(basename "${target_path}") to $(basename "${backup_path}")"
}


stop_klipper() {
    report_status "Stopping ${KLIPPER_SERVICE}"
    sudo systemctl stop "${KLIPPER_SERVICE}"
    KLIPPER_STOPPED=1
}


link_config_file() {
    source_name="$1"
    target_path="${PRINTER_CONFIG_PATH}/${source_name}"

    backup_existing_path "${target_path}"
    ln -s "${SCRIPT_DIR}/${source_name}" "${target_path}"
    echo "Linked ${source_name}"
}


copy_config_file() {
    source_name="$1"
    target_path="${PRINTER_CONFIG_PATH}/${source_name}"

    backup_existing_path "${target_path}"
    cp "${SCRIPT_DIR}/${source_name}" "${target_path}"
    echo "Copied ${source_name}"
}


install_configs() {
    report_status "Installing printer config files into ${PRINTER_CONFIG_PATH}"
    link_config_file "printer.cfg"
    link_config_file "printer_mcu.cfg"
    copy_config_file "printer_mcu1.cfg"
}


restart_klipper() {
    if [ "${KLIPPER_STOPPED}" -ne 1 ]; then
        return
    fi

    report_status "Restarting ${KLIPPER_SERVICE}"
    sudo systemctl restart "${KLIPPER_SERVICE}"
    KLIPPER_STOPPED=0
}


cleanup() {
    if [ "${KLIPPER_STOPPED}" -eq 1 ]; then
        echo
        echo "Installer aborted after stopping ${KLIPPER_SERVICE}. Attempting to start it again."
        restart_klipper
    fi
}


print_update_manager_instructions() {
    report_status "Moonraker Update Manager"
    echo "Add the section below to ${PRINTER_CONFIG_PATH}/moonraker.conf"
    echo "Template source: ${MOONRAKER_UPDATE_FILE}"
    echo
    cat "${MOONRAKER_UPDATE_FILE}"
}


main() {
    trap cleanup EXIT
    resolve_script_dir
    check_required_files
    ensure_printer_config_path
    stop_klipper
    install_configs
    print_update_manager_instructions
    restart_klipper
    trap - EXIT
}


main "$@"
