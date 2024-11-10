#!/bin/bash

# Function to execute scripts for the Controller node
install_controller() {
    echo "${YELLOW}Installing services on Controller Node...${RESET}"
    
    ./controller/ctl_01_config_ip.sh
    ./controller/ctl_02_env_setup.sh
    ./controller/ctl_03_keystone_install.sh
    ./controller/ctl_04_glance_install.sh
    ./controller/ctl_05_placement_install.sh
    ./controller/ctl_06_nova_install.sh
    ./controller/ctl_07_neutron_install.sh
    ./controller/ctl_08_horizon_install.sh
    ./controller/ctl_09_cinder_install.sh
    ./controller/ctl_10_pre_launch_instance.sh

    echo "${GREEN}Controller Node installation completed.${RESET}"
}

# Function to execute scripts for the Compute node
install_compute() {
    echo "${YELLOW}Installing services on Compute Node...${RESET}"
    
    ./compute/cp_01_config_ip.sh
    ./compute/cp_02_env_setup.sh
    ./compute/cp_03_nova_install.sh
    ./compute/cp_04_neutron_install.sh

    echo "${GREEN}Compute Node installation completed.${RESET}"
}

# Function to execute scripts for the Storage node
install_storage() {
    echo "${YELLOW}Installing services on Storage Node...${RESET}"
    
    ./block/bk_01_cinder.sh

    echo "${GREEN}Storage Node installation completed.${RESET}"
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
        echo "${RED}Invalid choice. Exiting.${RESET}"
        exit 1
        ;;
esac

echo "${GREEN}Installation process completed.${RESET}"
