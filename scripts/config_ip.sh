#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to change the hostname
change_hostname() {
    local hostname_var="$1"
    local hostname="${!hostname_var}"
    if [ -n "$hostname" ]; then
        echo "${YELLOW}Changing hostname to ${GREEN}$hostname${RESET}..."

        # Update /etc/hostname
        echo "$hostname" | sudo tee /etc/hostname > /dev/null

        # Update /etc/hosts (replace old hostname with new one and comment out 127.0.1.1)
        current_hostname=$(hostname)
        sudo sed -i "s/$current_hostname/$hostname/g" /etc/hosts
        sudo sed -i "s/^127.0.1.1/#127.0.1.1/" /etc/hosts

        # Apply the new hostname immediately
        sudo hostnamectl set-hostname "$hostname"
        echo "${GREEN}Hostname changed to $hostname.${RESET}"
    else
        echo "${RED}Hostname variable is not set in config.cfg. Skipping hostname change.${RESET}"
    fi
}

# Function to update /etc/hosts with additional entries
update_hosts_file() {
    echo "${YELLOW}Updating /etc/hosts with additional entries...${RESET}"

    if [ -n "$CTL_MANAGEMENT" ] && [ -n "$CTL_HOSTNAME" ] && \
       [ -n "$COM_MANAGEMENT" ] && [ -n "$COM_HOSTNAME" ] && \
       [ -n "$BLK_MANAGEMENT" ] && [ -n "$BLK_HOSTNAME" ]; then
        
        sudo tee -a /etc/hosts > /dev/null << EOF

# Custom host entries
$CTL_MANAGEMENT $CTL_HOSTNAME
$COM_MANAGEMENT $COM_HOSTNAME
$BLK_MANAGEMENT $BLK_HOSTNAME
EOF
        echo "${GREEN}/etc/hosts updated successfully with new entries.${RESET}"
    else
        echo "${RED}One or more required variables are missing in config.cfg. Skipping hosts file update.${RESET}"
    fi
}

# Function to change the IP address in the netplan configuration
change_ip() {
    local management_ip_var="$1"
    local provider_ip_var="$2"
    local host_control_ip_var="$3"
    local management_ip="${!management_ip_var}"
    local provider_ip="${!provider_ip_var}"
    local host_control_ip="${!host_control_ip_var}"

    # Define the netplan file path (only YAML file in /etc/netplan/)
    NETPLAN_FILE=$(find /etc/netplan/ -type f -name "*.yaml" | head -n 1)

    if [ -z "$NETPLAN_FILE" ]; then
        echo "${RED}Error: No netplan file found in /etc/netplan/${RESET}"
        exit 1
    fi

    if [ -n "$management_ip" ] && [ -n "$provider_ip" ] && [ -n "$host_control_ip" ]; then
        echo "${YELLOW}Updating IP configuration...${RESET}"
        
        cat << EOF | sudo tee $NETPLAN_FILE > /dev/null
network:
  ethernets:
    $INTERFACE_HOST_CONTROL:
      dhcp4: no
      addresses:
        - ${host_control_ip}/${NETMASK}
      
    $INTERFACE_MANAGEMENT:
      dhcp4: no
      addresses:
        - ${management_ip}/${NETMASK}
      routes:
        - to: 0.0.0.0/0
          via: ${GW_MANAGEMENT}
      nameservers:
        addresses:
          - 8.8.8.8

    $INTERFACE_PROVIDER:
      dhcp4: no
      addresses:
        - ${provider_ip}/${NETMASK}
      routes:
        - to: 0.0.0.0/0
          via: ${GW_PROVIDER}
      nameservers:
        addresses:
          - 8.8.8.8

  version: 2
EOF

        sudo netplan apply
        echo "${GREEN}IP configuration updated successfully.${RESET}"
    else
        echo "${RED}IP addresses or gateway are missing in config.cfg. Skipping IP configuration.${RESET}"
    fi
}

# Prompt user for node selection
echo "Select the node to configure:"
echo "1) Controller"
echo "2) Compute"
echo "3) Block Storage"
read -p "Enter the number corresponding to the node: " node_choice

case $node_choice in
    1)
        change_hostname CTL_HOSTNAME
        change_ip CTL_MANAGEMENT CTL_PROVIDER CTL_HOST_CONTROL
        ;;
    2)
        change_hostname COM_HOSTNAME
        change_ip COM_MANAGEMENT COM_PROVIDER COM_HOST_CONTROL
        ;;
    3)
        change_hostname BLK_HOSTNAME
        change_ip BLK_MANAGEMENT BLK_PROVIDER BLK_HOST_CONTROL
        ;;
    *)
        echo "${RED}Invalid choice. Exiting.${RESET}"
        exit 1
        ;;
esac

update_hosts_file

sudo reboot

echo "${GREEN}All tasks completed.${RESET}"
