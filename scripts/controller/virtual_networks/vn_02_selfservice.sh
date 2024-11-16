#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to create self-service network, subnet, and router with provider connectivity
create_self_service_network() {
    source /root/demo-openrc

    sleep 2

    echo "${YELLOW}Creating self-service network...${RESET}"
    openstack network create selfservice
    echo "${GREEN}Self-service network created successfully.${RESET}"

    echo "${YELLOW}Creating a subnet on the self-service network...${RESET}"
    openstack subnet create --network selfservice \
    --dns-nameserver $OS_MANAGEMENT_DNS --gateway $OS_MANAGEMENT_GATEWAY \
    --subnet-range $OS_MANAGEMENT_SUBNET selfservice
    echo "${GREEN}Self-service subnet created successfully.${RESET}"

    echo "${YELLOW}Creating router...${RESET}"
    openstack router create router
    echo "${GREEN}Router created successfully.${RESET}"

    echo "${YELLOW}Adding self-service subnet to router as an interface...${RESET}"
    openstack router add subnet router selfservice
    echo "${GREEN}Self-service subnet added to router successfully.${RESET}"

    echo "${YELLOW}Setting provider network as router gateway...${RESET}"
    openstack router set router --external-gateway provider
    echo "${GREEN}Provider network set as router gateway successfully.${RESET}"

    ip netns
    openstack port list --router router

    echo "${GREEN}Self-service network setup with router completed.${RESET}"
}