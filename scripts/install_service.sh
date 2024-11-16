#!/bin/bash

# File to store installed services
STATUS_FILE="services_status.log"

# Initialize status file if it doesn't exist
if [[ ! -f $STATUS_FILE ]]; then
    touch $STATUS_FILE
fi

# Function to check if a service is installed
is_installed() {
    grep -q "$1" "$STATUS_FILE"
}

# Function to mark a service as installed
mark_installed() {
    echo "$1" >> "$STATUS_FILE"
}

# Function to display service status
service_status() {
    if is_installed "$1"; then
        echo "(installed)"
    else
        echo ""
    fi
}

# Function to install services on the Controller node
install_controller() {
    echo "Select services to install on Controller Node (e.g., 1 2 or 1-4):"
    echo "1) Environment Setup $(service_status "Controller-1")"
    echo "2) Keystone $(service_status "Controller-2")"
    echo "3) Glance $(service_status "Controller-3")"
    echo "4) Placement $(service_status "Controller-4")"
    echo "5) Nova $(service_status "Controller-5")"
    echo "6) Neutron $(service_status "Controller-6")"
    echo "7) Horizon $(service_status "Controller-7")"
    echo "8) Cinder $(service_status "Controller-8")"
    echo "9) Pre-launch Instance $(service_status "Controller-9")"
    echo "A) All"
    read -p "Enter your choice: " service_choice

    install_service() {
        if is_installed "Controller-$1"; then
            echo "Service $1 is already installed."
        else
            case $1 in
                1) ./controller/ctl_02_env_setup.sh ;;
                2) ./controller/ctl_03_keystone_install.sh ;;
                3) ./controller/ctl_04_glance_install.sh ;;
                4) ./controller/ctl_05_placement_install.sh ;;
                5) ./controller/ctl_06_nova_install.sh ;;
                6) ./controller/ctl_07_neutron_install.sh ;;
                7) ./controller/ctl_08_horizon_install.sh ;;
                8) ./controller/ctl_09_cinder_install.sh ;;
                9) ./controller/ctl_10_pre_launch_instance.sh ;;
                *) echo "Invalid service number: $1" ;;
            esac
            mark_installed "Controller-$1"
        fi
    }

    if [[ "$service_choice" =~ ^[Aa]$ ]]; then
        for i in {1..9}; do
            install_service "$i"
        done
    else
        IFS=' ' read -r -a choices <<< "$service_choice"
        for choice in "${choices[@]}"; do
            if [[ "$choice" =~ ^[0-9]+-[0-9]+$ ]]; then
                IFS='-' read -r start end <<< "$choice"
                for ((i=start; i<=end; i++)); do
                    install_service "$i"
                done
            else
                install_service "$choice"
            fi
        done
    fi

    echo "Controller Node installation completed."
}

# Function to install services on the Compute node
install_compute() {
    echo "Select services to install on Compute Node (e.g., 1 2 or 1-2):"
    echo "1) Environment Setup $(service_status "Compute-1")"
    echo "2) Nova $(service_status "Compute-2")"
    echo "3) Neutron $(service_status "Compute-3")"
    echo "A) All"
    read -p "Enter your choice: " service_choice

    install_service() {
        if is_installed "Compute-$1"; then
            echo "Service $1 is already installed."
        else
            case $1 in
                1) ./compute/cp_02_env_setup.sh ;;
                2) ./compute/cp_03_nova_install.sh ;;
                3) ./compute/cp_04_neutron_install.sh ;;
                *) echo "Invalid service number: $1" ;;
            esac
            mark_installed "Compute-$1"
        fi
    }

    if [[ "$service_choice" =~ ^[Aa]$ ]]; then
        for i in {1..3}; do
            install_service "$i"
        done
    else
        IFS=' ' read -r -a choices <<< "$service_choice"
        for choice in "${choices[@]}"; do
            if [[ "$choice" =~ ^[0-9]+-[0-9]+$ ]]; then
                IFS='-' read -r start end <<< "$choice"
                for ((i=start; i<=end; i++)); do
                    install_service "$i"
                done
            else
                install_service "$choice"
            fi
        done
    fi

    echo "Compute Node installation completed."
}

# Function to install services on the Storage node
install_storage() {
    echo "Select services to install on Storage Node (e.g., 1 or A for all):"
    echo "1) Environment Setup $(service_status "Storage-1")"
    echo "2) Cinder $(service_status "Storage-2")"
    echo "A) All"
    read -p "Enter your choice: " service_choice

    install_service() {
        if is_installed "Storage-$1"; then
            echo "Service $1 is already installed."
        else
            case $1 in
                1) ./block/blk_01_env_setup.sh ;;
                2) ./block/blk_02_cinder.sh ;;
                *) echo "Invalid service number: $1" ;;
            esac
            mark_installed "Storage-$1"
        fi
    }

    if [[ "$service_choice" =~ ^[Aa]$ ]]; then
        for i in {1..2}; do
            install_service "$i"
        done
    else
        IFS=' ' read -r -a choices <<< "$service_choice"
        for choice in "${choices[@]}"; do
            if [[ "$choice" =~ ^[0-9]+-[0-9]+$ ]]; then
                IFS='-' read -r start end <<< "$choice"
                for ((i=start; i<=end; i++)); do
                    install_service "$i"
                done
            else
                install_service "$choice"
            fi
        done
    fi

    echo "Storage Node installation completed."
}

# Main script logic
echo "Select the node to install:"
echo "1) Controller Node"
echo "2) Compute Node"
echo "3) Storage Node"
read -p "Enter the number corresponding to the node: " node_choice

case $node_choice in
    1) install_controller ;;
    2) install_compute ;;
    3) install_storage ;;
    *) echo "Invalid choice. Exiting." ;;
esac

echo "Installation process completed."
