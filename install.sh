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
    source_path="${SCRIPT_DIR}/${source_name}"

    if [ -L "${target_path}" ] && [ "$(readlink -f "${target_path}")" = "$(readlink -f "${source_path}")" ]; then
        echo "Keeping existing ${source_name} link"
        return
    fi

    backup_existing_path "${target_path}"
    ln -s "${source_path}" "${target_path}"
    echo "Linked ${source_name}"
}


prompt_and_copy_config_file() {
    source_name="$1"
    target_path="${PRINTER_CONFIG_PATH}/${source_name}"
    replace_existing=""

    if [ -e "${target_path}" ] || [ -L "${target_path}" ]; then
        while true; do
            printf "Replace existing %s? [y/N] " "${source_name}"
            read -r replace_existing

            case "${replace_existing}" in
                [Yy]|[Yy][Ee][Ss])
                    backup_existing_path "${target_path}"
                    break
                    ;;
                ""|[Nn]|[Nn][Oo])
                    echo "Keeping existing ${source_name}"
                    return
                    ;;
                *)
                    echo "Please answer y or n."
                    ;;
            esac
        done
    fi

    cp "${SCRIPT_DIR}/${source_name}" "${target_path}"
    echo "Copied ${source_name}"
}

copy_config_file_with_backup() {
    source_name="$1"
    target_path="${PRINTER_CONFIG_PATH}/${source_name}"

    backup_existing_path "${target_path}"
    cp "${SCRIPT_DIR}/${source_name}" "${target_path}"
    echo "Copied ${source_name}"
}

install_configs() {
    report_status "Installing printer config files into ${PRINTER_CONFIG_PATH}"
    prompt_and_copy_config_file "printer.cfg"
    link_config_file "printer_mtx6.cfg"
    link_config_file "printer_mtx6_microprobe.cfg"
    link_config_file "printer_giga.cfg"
    link_config_file "printer_giga_bed.cfg"
    link_config_file "printer_giga_heating_and_fans.cfg"
    link_config_file "printer_giga_macros_and_homing.cfg"
    link_config_file "printer_giga_steppers.cfg"
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
    ensure_printer_config_path
    stop_klipper
    install_configs
    print_update_manager_instructions
    restart_klipper
    trap - EXIT
}


main "$@"
