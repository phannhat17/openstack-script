#!/bin/bash

# Load configuration from config.cfg
source ../config.cfg

# Function to install LVM and supporting tools
install_lvm_tools() {
    echo "${YELLOW}Installing LVM and supporting tools...${RESET}"
    sudo apt install -y lvm2 thin-provisioning-tools
    echo "${GREEN}LVM and supporting tools installed successfully.${RESET}"
}

# Function to create LVM physical volume and volume group
configure_lvm() {
    echo "${YELLOW}Configuring LVM for Block Storage...${RESET}"
    
    # Create physical volume
    sudo pvcreate /dev/sdb
    
    # Create volume group
    sudo vgcreate cinder-volumes /dev/sdb

    # Update LVM configuration to scan only for specific devices
    local lvm_conf="/etc/lvm/lvm.conf"
    sudo sed -i '/^ *filter =/d' $lvm_conf
    echo 'filter = [ "a/sda/", "a/sdb/", "r/.*/"]' | sudo tee -a $lvm_conf > /dev/null

    echo "${GREEN}LVM configured with physical volume and volume group.${RESET}"
}

# Function to install and configure Cinder components
install_configure_cinder() {
    echo "${YELLOW}Installing and configuring Cinder components...${RESET}"
    
    # Install required packages
    sudo apt install -y cinder-volume tgt

    # Configure /etc/cinder/cinder.conf
    local cinder_conf="/etc/cinder/cinder.conf"
    local cinder_conf_bak="/etc/cinder/cinder.conf.bak"
    cp $cinder_conf $cinder_conf_bak
    egrep -v "^#|^$" $cinder_conf_bak > $cinder_conf

    crudini --set "$cinder_conf" "database" "connection" "mysql+pymysql://cinder:$CINDER_DBPASS@controller/cinder"

    crudini --set "$cinder_conf" "DEFAULT" "transport_url" "rabbit://openstack:$RABBIT_PASS@controller"
    crudini --set "$cinder_conf" "DEFAULT" "auth_strategy" "keystone"
    crudini --set "$cinder_conf" "DEFAULT" "my_ip" "$BLK_MANAGEMENT"
    crudini --set "$cinder_conf" "DEFAULT" "enabled_backends" "lvm"
    crudini --set "$cinder_conf" "DEFAULT" "glance_api_servers" "http://controller:9292"

    crudini --set "$cinder_conf" "keystone_authtoken" "www_authenticate_uri" "http://controller:5000"
    crudini --set "$cinder_conf" "keystone_authtoken" "auth_url" "http://controller:5000"
    crudini --set "$cinder_conf" "keystone_authtoken" "memcached_servers" "controller:11211"
    crudini --set "$cinder_conf" "keystone_authtoken" "auth_type" "password"
    crudini --set "$cinder_conf" "keystone_authtoken" "project_domain_name" "default"
    crudini --set "$cinder_conf" "keystone_authtoken" "user_domain_name" "default"
    crudini --set "$cinder_conf" "keystone_authtoken" "project_name" "service"
    crudini --set "$cinder_conf" "keystone_authtoken" "username" "cinder"
    crudini --set "$cinder_conf" "keystone_authtoken" "password" "$CINDER_PASS"

    crudini --set "$cinder_conf" "lvm" "volume_driver" "cinder.volume.drivers.lvm.LVMVolumeDriver"
    crudini --set "$cinder_conf" "lvm" "volume_group" "cinder-volumes"
    crudini --set "$cinder_conf" "lvm" "target_protocol" "iscsi"
    crudini --set "$cinder_conf" "lvm" "target_helper" "tgtadm"

    crudini --set "$cinder_conf" "oslo_concurrency" "lock_path" "/var/lib/cinder/tmp"

    echo "${GREEN}Cinder configuration updated.${RESET}"
}

# Function to configure tgt for Cinder volumes
configure_tgt() {
    echo "${YELLOW}Configuring tgt for Cinder volumes...${RESET}"
    
    # Create tgt configuration for Cinder
    echo 'include /var/lib/cinder/volumes/*' | sudo tee /etc/tgt/conf.d/cinder.conf > /dev/null

    echo "${GREEN}tgt configured successfully.${RESET}"
}

# Function to finalize installation by restarting services
finalize_installation() {
    echo "${YELLOW}Finalizing Block Storage installation...${RESET}"

    # Restart tgt and Cinder volume service
    sudo service tgt restart
    sudo service cinder-volume restart

    echo "${GREEN}Block Storage services restarted successfully.${RESET}"
}

# Run functions in sequence
install_lvm_tools
configure_lvm
install_configure_cinder
configure_tgt
finalize_installation

echo "${GREEN}OpenStack Block Storage (Cinder) setup on storage node completed.${RESET}"
