#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function update and upgrade for Monitor
update_upgrade () {
    echo "${YELLOW}Update and Update Monitor...${RESET}"
	apt-get update -y&& apt-get upgrade -y
    echo "${GREEN}Update and Update Monitor successfully.${RESET}"
}

# Function to add OpenStack repository
add_repo() {
    echo "${YELLOW}Adding OpenStack Caracal repository...${RESET}"
    sudo add-apt-repository cloud-archive:caracal -y
    echo "${GREEN}Repository added successfully.${RESET}"
}

# Function to install crudini
install_crudini() {
    echo "${YELLOW}Installing crudini...${RESET}"
    sudo apt install -y crudini
    echo "${GREEN}crudini installed successfully.${RESET}"
}

# Function to install OpenStack client package
install_ops_packages() {
    echo "${YELLOW}Installing OpenStack client...${RESET}"
    sudo apt-get install python3-openstackclient -y
    echo "${GREEN}OpenStack client installed successfully.${RESET}"
}

# Function to install and configure Chrony NTP service
config_ntp_service() {
    echo "${YELLOW}Installing and configuring Chrony...${RESET}"
    
    # Install Chrony
    sudo apt install -y chrony

    # Configure Chrony
    local chrony_conf="/etc/chrony/chrony.conf"
    echo "allow $MANAGEMENT_NW/24" >> $chrony_conf

    # Restart Chrony service
    sudo service chrony restart
    echo "${GREEN}Chrony configured successfully.${RESET}"
}

# Function to install jq
install_jq() {
    echo -e "${YELLOW}Installing jq...${RESET}"
    sudo apt install -y jq
    echo -e "${GREEN}jq installed successfully.${RESET}"
}

# Run the functions in sequence
update_upgrade
add_repo
install_jq
install_crudini
install_ops_packages
config_ntp_service

echo "${GREEN}All components installed and configured.${RESET}"
