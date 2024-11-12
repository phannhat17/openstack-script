#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to install the Nova compute service
install_nova_compute() {
    echo "${YELLOW}Installing Nova Compute...${RESET}"
    sudo apt install -y nova-compute
    echo "${GREEN}Nova Compute installed successfully.${RESET}"
}

# Function to configure nova.conf
configure_nova_conf() {
    local nova_conf="/etc/nova/nova.conf"
    local nova_conf_bak="/etc/nova/nova.conf.bak"
    
    # Backup and clean up nova.conf
    echo "${YELLOW}Configuring $nova_conf...${RESET}"
    cp $nova_conf $nova_conf_bak
    egrep -v "^#|^$" $nova_conf_bak > $nova_conf

    # [DEFAULT] section
    crudini --set "$nova_conf" "DEFAULT" "transport_url" "rabbit://openstack:$RABBIT_PASS@controller"
    crudini --set "$nova_conf" "DEFAULT" "my_ip" "$COM_PROVIDER"

    # [api] section
    crudini --set "$nova_conf" "api" "auth_strategy" "keystone"

    # Comment out any other options in [keystone_authtoken]
    sed -i "/^\[keystone_authtoken\]/,/^\[/ s/^/#/" $nova_conf
    crudini --set "$nova_conf" "keystone_authtoken" "www_authenticate_uri" "http://controller:5000/"
    crudini --set "$nova_conf" "keystone_authtoken" "auth_url" "http://controller:5000/"
    crudini --set "$nova_conf" "keystone_authtoken" "memcached_servers" "controller:11211"
    crudini --set "$nova_conf" "keystone_authtoken" "auth_type" "password"
    crudini --set "$nova_conf" "keystone_authtoken" "project_domain_name" "Default"
    crudini --set "$nova_conf" "keystone_authtoken" "user_domain_name" "Default"
    crudini --set "$nova_conf" "keystone_authtoken" "project_name" "service"
    crudini --set "$nova_conf" "keystone_authtoken" "username" "nova"
    crudini --set "$nova_conf" "keystone_authtoken" "password" "$NOVA_PASS"

    # [service_user] section
    crudini --set "$nova_conf" "service_user" "send_service_user_token" "true"
    crudini --set "$nova_conf" "service_user" "auth_url" "http://controller:5000/"
    crudini --set "$nova_conf" "service_user" "auth_strategy" "keystone"
    crudini --set "$nova_conf" "service_user" "auth_type" "password"
    crudini --set "$nova_conf" "service_user" "project_domain_name" "Default"
    crudini --set "$nova_conf" "service_user" "project_name" "service"
    crudini --set "$nova_conf" "service_user" "user_domain_name" "Default"
    crudini --set "$nova_conf" "service_user" "username" "nova"
    crudini --set "$nova_conf" "service_user" "password" "$NOVA_PASS"

    # [vnc] section
    crudini --set "$nova_conf" "vnc" "enabled" "true"
    crudini --set "$nova_conf" "vnc" "server_listen" "0.0.0.0"
    crudini --set "$nova_conf" "vnc" "server_proxyclient_address" "\$my_ip"
    crudini --set "$nova_conf" "vnc" "novncproxy_base_url" "http://controller:6080/vnc_auto.html"

    # [glance] section
    crudini --set "$nova_conf" "glance" "api_servers" "http://controller:9292"

    # [oslo_concurrency] section
    crudini --set "$nova_conf" "oslo_concurrency" "lock_path" "/var/lib/nova/tmp"

    # Comment out any other options in [placement]
    sed -i "/^\[placement\]/,/^\[/ s/^/#/" $nova_conf
    crudini --set "$nova_conf" "placement" "region_name" "RegionOne"
    crudini --set "$nova_conf" "placement" "project_domain_name" "Default"
    crudini --set "$nova_conf" "placement" "project_name" "service"
    crudini --set "$nova_conf" "placement" "auth_type" "password"
    crudini --set "$nova_conf" "placement" "user_domain_name" "Default"
    crudini --set "$nova_conf" "placement" "auth_url" "http://controller:5000/v3"
    crudini --set "$nova_conf" "placement" "username" "placement"
    crudini --set "$nova_conf" "placement" "password" "$PLACEMENT_PASS"

    echo "${GREEN}Nova configuration updated in $nova_conf.${RESET}"
}

# Function to configure nova-compute.conf
configure_nova_compute_conf() {
    local nova_compute_conf="/etc/nova/nova-compute.conf"
    local nova_compute_conf_bak="/etc/nova/nova-compute.conf.bak"
    
    # Backup and configure nova-compute.conf
    echo "${YELLOW}Configuring $nova_compute_conf...${RESET}"
    cp $nova_compute_conf $nova_compute_conf_bak
    egrep -v "^#|^$" $nova_compute_conf_bak > $nova_compute_conf

    # Check for hardware acceleration support and configure virt_type
    if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo) -eq 0 ]]; then
        echo "${YELLOW}Configuring libvirt to use QEMU (no hardware acceleration)...${RESET}"
        crudini --set "$nova_compute_conf" "libvirt" "virt_type" "qemu"
    else
        echo "${GREEN}Hardware acceleration is supported; no need to configure virt_type.${RESET}"
    fi
}

# Function to restart the Nova Compute service
restart_nova_compute() {
    echo "${YELLOW}Restarting Nova Compute service...${RESET}"
    sudo service nova-compute restart
    echo "${GREEN}Nova Compute service restarted successfully.${RESET}"
}

# Run all functions in sequence
install_nova_compute
configure_nova_conf
configure_nova_compute_conf
restart_nova_compute

echo "${GREEN}OpenStack Compute (Nova) setup on compute node completed.${RESET}"
