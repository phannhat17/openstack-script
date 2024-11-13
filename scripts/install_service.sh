#!/bin/bash
set -e

# Function to install services on the Controller node
install_controller() {
    echo "Select services to install on Controller Node (e.g., 1 2 or 1-4):"
    echo "1) Keystone"
    echo "2) Glance"
    echo "3) Nova"
    echo "4) Neutron"
    echo "5) Cinder"
    echo "A) All"
    read -p "Enter your choice: " service_choice

    # Function to install a specific service by number
    install_service() {
        case $1 in
            1)
                ./controller/ctl_03_keystone_install.sh
                ;;
            2)
                ./controller/ctl_04_glance_install.sh
                ;;
            3)
                ./controller/ctl_06_nova_install.sh
                ;;
            4)
                ./controller/ctl_07_neutron_install.sh
                ;;
            5)
                ./controller/ctl_09_cinder_install.sh
                ;;
            *)
                echo "Invalid service number: $1"
                ;;
        esac
    }

    # Handle the "All" option
    if [[ "$service_choice" =~ [Aa] ]]; then
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
        # Split input by spaces
        IFS=' ' read -r -a choices <<< "$service_choice"
        for choice in "${choices[@]}"; do
            if [[ "$choice" =~ ^[0-9]+-[0-9]+$ ]]; then
                # Handle ranges like 1-4
                IFS='-' read -r start end <<< "$choice"
                for ((i=start; i<=end; i++)); do
                    install_service "$i"
                done
            else
                # Handle individual numbers
                install_service "$choice"
            fi
        done
    fi

    echo "Controller Node installation completed."
}

# Function to install services on the Compute node
install_compute() {
    echo "Select services to install on Compute Node (e.g., 1 2 or 1-2):"
    echo "1) Nova"
    echo "2) Neutron"
    echo "A) All"
    read -p "Enter your choice: " service_choice

    install_service() {
        case $1 in
            1)
                ./compute/cp_03_nova_install.sh
                ;;
            2)
                ./compute/cp_04_neutron_install.sh
                ;;
            *)
                echo "Invalid service number: $1"
                ;;
        esac
    }

    if [[ "$service_choice" =~ [Aa] ]]; then
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
    echo "Installing services on Storage Node..."
    ./block/blk_01_env_setup.sh
    ./block/blk_02_cinder.sh
    echo "Storage Node installation completed."
}

# Main script logic
echo "Select the node to install:"
echo "1) Controller Node"
echo "2) Compute Node"
echo "3) Storage Node"
read -p "Enter the number corresponding to the node: " node_choice

case $node_choice in
    1)
        install_controller
        ;;
    2)
        install_compute
        ;;
    3)
        install_storage
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "Installation process completed."
