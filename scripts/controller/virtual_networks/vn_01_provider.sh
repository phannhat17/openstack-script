#!/bin/bash

# Load configuration from config.cfg
source ../../config.cfg

# Function to create provider network and subnet
create_provider_network_and_subnet() {
    source /root/admin-openrc

    echo "${YELLOW}Creating the provider network...${RESET}"
    openstack network create  --share --external \
    --provider-physical-network provider \
    --provider-network-type flat provider
    echo "${GREEN}Provider network created successfully.${RESET}"

    echo "${YELLOW}Creating a subnet on the provider network...${RESET}"
    openstack subnet create --network provider \
      --allocation-pool start=$PROVIDER_IP_START,end=$PROVIDER_IP_END \
      --dns-nameserver $PROVIDER_DNS --gateway $PROVIDER_GATEWAY \
      --subnet-range $PROVIDER_SUBNET provider

    echo "${GREEN}Provider subnet created successfully.${RESET}"
}
