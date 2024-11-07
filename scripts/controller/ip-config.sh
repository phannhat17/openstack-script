#!/bin/bash

# Load configuration from config.cfg
source ../config.cfg

# Function to set the root password manually
set_root_password() {
    echo "${YELLOW}Setting root password...${RESET}"
    sudo passwd root
}

# Function to change the hostname
change_hostname() {
    if [ -n "$CTL_HOSTNAME" ]; then
        echo "${YELLOW}Changing hostname to ${GREEN}$CTL_HOSTNAME${RESET}..."

        # Update /etc/hostname
        echo "$CTL_HOSTNAME" | sudo tee /etc/hostname > /dev/null

        # Update /etc/hosts (replace old hostname with new one and comment out 127.0.1.1)
        current_hostname=$(hostname)
        sudo sed -i "s/$current_hostname/$CTL_HOSTNAME/g" /etc/hosts
        sudo sed -i "s/^127.0.1.1/#127.0.1.1/" /etc/hosts

        # Apply the new hostname immediately
        sudo hostnamectl set-hostname "$CTL_HOSTNAME"
        echo "${GREEN}Hostname changed to $CTL_HOSTNAME.${RESET}"
    else
        echo "${RED}CTL_HOSTNAME variable is not set in config.cfg. Skipping hostname change.${RESET}"
    fi
}

# Function to change the IP address in the netplan configuration
change_ip() {
    # Define the netplan file path (only YAML file in /etc/netplan/)
    NETPLAN_FILE=$(find /etc/netplan/ -type f -name "*.yaml" | head -n 1)

    # Ensure the netplan file was found
    if [ -z "$NETPLAN_FILE" ]; then
        echo "${RED}Error: No netplan file found in /etc/netplan/${RESET}"
        exit 1
    fi

    # Check if IP addresses and gateway are set in config.cfg
    if [ -n "$CTL_HOSTONLY" ] && [ -n "$CTL_NAT" ] && [ -n "$GW_NAT" ]; then
        echo "${YELLOW}Updating IP configuration...${RESET}"
        
        # Modify the netplan configuration
        cat << EOF | sudo tee $NETPLAN_FILE > /dev/null
network:
  ethernets:
    ens37:
      dhcp4: no
      addresses:
        - ${CTL_HOSTONLY}/${NETMASK}

    ens33:
      dhcp4: no
      addresses:
        - ${CTL_NAT}/${NETMASK}
      routes:
        - to: 0.0.0.0/0
          via: ${GW_NAT}
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

  version: 2
EOF

        # Apply the netplan configuration
        sudo netplan apply
        echo "${GREEN}IP configuration updated successfully.${RESET}"
    else
        echo "${RED}IP addresses or gateway are missing in config.cfg. Skipping IP configuration.${RESET}"
    fi
}

# Run all functions as per the required sequence

# Step 1: Set root password manually
set_root_password

# Step 2: Change the hostname based on config.cfg
change_hostname

# Step 3: Change IP configuration based on config.cfg
change_ip

echo "${GREEN}All tasks completed.${RESET}"
