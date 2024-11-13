#!/bin/bash
set -e

# Load configuration from config.cfg
source config.cfg

source controller/virtual_networks/vn_01_provider.sh
source controller/virtual_networks/vn_02_selfservice.sh

# Function to create the m1.nano flavor
create_flavor() {
    source /root/admin-openrc

    echo "${YELLOW}Creating m1.nano flavor...${RESET}"
    openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano
    echo "${GREEN}m1.nano flavor created successfully.${RESET}"
}

# Function to generate and add SSH key pair
create_keypair() {
    source /root/admin-openrc

    echo "${YELLOW}Generating SSH key pair...${RESET}"
    
    # Check if SSH key already exists; if not, generate a new key
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        ssh-keygen -q -N ""
    fi

    # Create key pair in OpenStack
    openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey

    openstack keypair list
    echo "${GREEN}SSH key pair created and added to OpenStack.${RESET}"
}

# Function to add security group rules
add_security_group_rules() {
    source /root/admin-openrc

    echo "${YELLOW}Adding security group rules...${RESET}"

    # Allow ICMP (ping)
    openstack security group rule create --proto icmp default
    echo "${GREEN}ICMP rule added to default security group.${RESET}"

    # Allow SSH access
    openstack security group rule create --proto tcp --dst-port 22 default
    echo "${GREEN}SSH rule added to default security group.${RESET}"
}

# Run all functions
create_provider_network_and_subnet
create_self_service_network
create_flavor
create_keypair
add_security_group_rules

echo "${GREEN}Setup completed.${RESET}"
