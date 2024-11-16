#!/bin/bash

# Function to install services on the Controller node
install_controller() {
    echo "Select services to install on Controller Node (e.g., 1 2 or 1-4):"
    echo "1) Environment Setup"
    echo "2) Keystone"
    echo "3) Glance"
    echo "4) Placement"
    echo "5) Nova"
    echo "6) Neutron"
    echo "7) Horizon"
    echo "8) Cinder"
    echo "9) Pre-launch Instance"
    echo "A) All"
    read -p "Enter your choice: " service_choice

    install_service() {
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
    }

    if [[ "$service_choice" =~ ^[Aa]$ ]]; then
        ./controller/ctl_02_env_setup.sh
        ./controller/ctl_03_keystone_install.sh
        ./controller/ctl_04_glance_install.sh
        ./controller/ctl_05_placement_install.sh
        ./controller/ctl_06_nova_install.sh
        ./controller/ctl_07_neutron_install.sh
        ./controller/ctl_08_horizon_install.sh
        ./controller/ctl_09_cinder_install.sh
        ./controller/ctl_10_pre_launch_instance.sh
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
    echo "1) Environment Setup"
    echo "2) Nova"
    echo "3) Neutron"
    echo "A) All"
    read -p "Enter your choice: " service_choice

    install_service() {
        case $1 in
            1) ./compute/cp_02_env_setup.sh ;;
            2) ./compute/cp_03_nova_install.sh ;;
            3) ./compute/cp_04_neutron_install.sh ;;
            *) echo "Invalid service number: $1" ;;
        esac
    }

    if [[ "$service_choice" =~ ^[Aa]$ ]]; then
        ./compute/cp_02_env_setup.sh
        ./compute/cp_03_nova_install.sh
        ./compute/cp_04_neutron_install.sh
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
    echo "1) Environment Setup"
    echo "2) Cinder"
    echo "A) All"
    read -p "Enter your choice: " service_choice

    install_service() {
        case $1 in
            1) ./block/blk_01_env_setup.sh ;;
            2) ./block/blk_02_cinder.sh ;;
            *) echo "Invalid service number: $1" ;;
        esac
    }

    if [[ "$service_choice" =~ ^[Aa]$ ]]; then
        ./block/blk_01_env_setup.sh
        ./block/blk_02_cinder.sh
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
