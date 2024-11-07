#!/bin/bash

# Load base function from base_function.sh
source ../base_function.sh

# Load configuration from config.cfg
source ../config.cfg

# Function to configure Neutron database
configure_neutron_database() {
    echo "${YELLOW}Configuring Neutron database...${RESET}"
    
    mysql -u root << EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
FLUSH PRIVILEGES;
EOF

    echo "${GREEN}Neutron database configured successfully.${RESET}"
}

# Function to create Neutron user and service credentials
create_neutron_user() {
    echo "${YELLOW}Creating Neutron user and service credentials...${RESET}"

    # Source admin credentials
    source /root/admin-openrc

    # Create Neutron user
    openstack user create --domain default --password $NEUTRON_PASS neutron

    # Add the admin role to the Neutron user in the service project
    openstack role add --project service --user neutron admin

    # Create the Neutron service entity
    openstack service create --name neutron --description "OpenStack Networking" network

    echo "${GREEN}Neutron user and service credentials created successfully.${RESET}"
}

# Function to create Neutron API endpoints
create_neutron_endpoints() {
    echo "${YELLOW}Creating Neutron API endpoints...${RESET}"

    # Create public, internal, and admin endpoints for Neutron
    openstack endpoint create --region RegionOne network public http://controller:9696
    openstack endpoint create --region RegionOne network internal http://controller:9696
    openstack endpoint create --region RegionOne network admin http://controller:9696

    echo "${GREEN}Neutron API endpoints created successfully.${RESET}"
}

# Function to install and configure Neutron
install_configure_neutron() {
    echo "${YELLOW}Installing and configuring Neutron...${RESET}"
    
    sudo apt install -y neutron-server neutron-plugin-ml2 \
                        neutron-openvswitch-agent neutron-l3-agent \
                        neutron-dhcp-agent neutron-metadata-agent

    local file="/etc/neutron/neutron.conf"
    append_if_missing "$file" "database" "connection" "mysql+pymysql://neutron:$NEUTRON_DBPASS@controller/neutron"
    append_if_missing "$file" "DEFAULT" "core_plugin" "ml2"
    append_if_missing "$file" "DEFAULT" "service_plugins" "router"
    append_if_missing "$file" "DEFAULT" "transport_url" "rabbit://openstack:$RABBIT_PASS@controller"
    append_if_missing "$file" "DEFAULT" "auth_strategy" "keystone"
    append_if_missing "$file" "DEFAULT" "notify_nova_on_port_status_changes" "true"
    append_if_missing "$file" "DEFAULT" "notify_nova_on_port_data_changes" "true"
    append_if_missing "$file" "keystone_authtoken" "www_authenticate_uri" "http://controller:5000"
    append_if_missing "$file" "keystone_authtoken" "auth_url" "http://controller:5000"
    append_if_missing "$file" "keystone_authtoken" "memcached_servers" "controller:11211"
    append_if_missing "$file" "keystone_authtoken" "auth_type" "password"
    append_if_missing "$file" "keystone_authtoken" "project_domain_name" "Default"
    append_if_missing "$file" "keystone_authtoken" "user_domain_name" "Default"
    append_if_missing "$file" "keystone_authtoken" "project_name" "service"
    append_if_missing "$file" "keystone_authtoken" "username" "neutron"
    append_if_missing "$file" "keystone_authtoken" "password" "$NEUTRON_PASS"
    append_if_missing "$file" "nova" "auth_url" "http://controller:5000"
    append_if_missing "$file" "nova" "auth_type" "password"
    append_if_missing "$file" "nova" "project_domain_name" "Default"
    append_if_missing "$file" "nova" "user_domain_name" "Default"
    append_if_missing "$file" "nova" "region_name" "RegionOne"
    append_if_missing "$file" "nova" "project_name" "service"
    append_if_missing "$file" "nova" "username" "nova"
    append_if_missing "$file" "nova" "password" "$NOVA_PASS"
    append_if_missing "$file" "oslo_concurrency" "lock_path" "/var/lib/neutron/tmp"

    echo "${GREEN}Neutron configuration updated.${RESET}"
}

# Function to configure the metadata agent
configure_metadata_agent() {
    echo "${YELLOW}Configuring Neutron metadata agent...${RESET}"
    
    local file="/etc/neutron/metadata_agent.ini"
    append_if_missing "$file" "DEFAULT" "nova_metadata_host" "controller"
    append_if_missing "$file" "DEFAULT" "metadata_proxy_shared_secret" "$METADATA_SECRET"

    echo "${GREEN}Metadata agent configuration updated.${RESET}"
}

# Function to configure the Modular Layer 2 (ML2) plugin
configure_ml2_plugin() {
    echo "${YELLOW}Configuring ML2 plugin...${RESET}"
    
    local file="/etc/neutron/plugins/ml2/ml2_conf.ini"
    append_if_missing "$file" "ml2" "type_drivers" "flat,vlan,vxlan"
    append_if_missing "$file" "ml2" "tenant_network_types" "vxlan"
    append_if_missing "$file" "ml2" "mechanism_drivers" "openvswitch,l2population"
    append_if_missing "$file" "ml2" "extension_drivers" "port_security"
    append_if_missing "$file" "ml2_type_flat" "flat_networks" "provider"
    append_if_missing "$file" "ml2_type_vxlan" "vni_ranges" "1:1000"

    echo "${GREEN}ML2 plugin configuration updated.${RESET}"
}

# Function to configure the Open vSwitch (OVS) agent
configure_openvswitch_agent() {
    echo "${YELLOW}Configuring Open vSwitch (OVS) agent...${RESET}"
    
    local file="/etc/neutron/plugins/ml2/openvswitch_agent.ini"
    append_if_missing "$file" "ovs" "bridge_mappings" "provider:$PROVIDER_BRIDGE_NAME"
    append_if_missing "$file" "ovs" "local_ip" "$CTL_HOSTONLY"
    append_if_missing "$file" "agent" "tunnel_types" "vxlan"
    append_if_missing "$file" "agent" "l2_population" "true"
    append_if_missing "$file" "securitygroup" "enable_security_group" "true"
    append_if_missing "$file" "securitygroup" "firewall_driver" "openvswitch"

    sudo ovs-vsctl add-br $PROVIDER_BRIDGE_NAME
    sudo ovs-vsctl add-port $PROVIDER_BRIDGE_NAME $PROVIDER_INTERFACE_NAME

    echo "${GREEN}Open vSwitch agent configured successfully.${RESET}"

    # Enable bridge filter support
    sudo modprobe br_netfilter
    sudo tee /etc/sysctl.d/99-sysctl.conf > /dev/null << SYSCTL_EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
SYSCTL_EOF
    sudo sysctl --system
}

# Function to configure layer-3 (L3) agent
configure_l3_agent() {
    echo "${YELLOW}Configuring L3 agent...${RESET}"
    
    local file="/etc/neutron/l3_agent.ini"
    append_if_missing "$file" "DEFAULT" "interface_driver" "openvswitch"

    echo "${GREEN}L3 agent configuration updated.${RESET}"
}

# Function to configure DHCP agent
configure_dhcp_agent() {
    echo "${YELLOW}Configuring DHCP agent...${RESET}"
    
    local file="/etc/neutron/dhcp_agent.ini"
    append_if_missing "$file" "DEFAULT" "interface_driver" "openvswitch"
    append_if_missing "$file" "DEFAULT" "dhcp_driver" "neutron.agent.linux.dhcp.Dnsmasq"
    append_if_missing "$file" "DEFAULT" "enable_isolated_metadata" "true"

    echo "${GREEN}DHCP agent configuration updated.${RESET}"
}

# Function to configure Nova to use Neutron
configure_nova_for_neutron() {
    echo "${YELLOW}Configuring Nova to use Neutron...${RESET}"
    
    local file="/etc/nova/nova.conf"
    append_if_missing "$file" "neutron" "auth_url" "http://controller:5000"
    append_if_missing "$file" "neutron" "auth_type" "password"
    append_if_missing "$file" "neutron" "project_domain_name" "Default"
    append_if_missing "$file" "neutron" "user_domain_name" "Default"
    append_if_missing "$file" "neutron" "region_name" "RegionOne"
    append_if_missing "$file" "neutron" "project_name" "service"
    append_if_missing "$file" "neutron" "username" "neutron"
    append_if_missing "$file" "neutron" "password" "$NEUTRON_PASS"
    append_if_missing "$file" "neutron" "service_metadata_proxy" "true"
    append_if_missing "$file" "neutron" "metadata_proxy_shared_secret" "$METADATA_SECRET"

    echo "${GREEN}Nova configured to use Neutron successfully.${RESET}"
}

# Populate the Neutron database
populate_neutron_database() {
    echo "${YELLOW}Populating Neutron database...${RESET}"
    su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
    echo "${GREEN}Neutron database populated successfully.${RESET}"
}

# Finalize Neutron installation
finalize_neutron_installation() {
    echo "${YELLOW}Finalizing Neutron installation...${RESET}"

    sudo service nova-api restart
    sudo service neutron-server restart
    sudo service neutron-openvswitch-agent restart
    sudo service neutron-dhcp-agent restart
    sudo service neutron-metadata-agent restart
    sudo service neutron-l3-agent restart

    echo "${GREEN}Neutron services restarted successfully.${RESET}"
}

# Run all functions in sequence
configure_neutron_database
create_neutron_user
create_neutron_endpoints
install_configure_neutron
configure_metadata_agent
configure_ml2_plugin
configure_openvswitch_agent
configure_l3_agent
configure_dhcp_agent
configure_nova_for_neutron
populate_neutron_database
finalize_neutron_installation

echo "${GREEN}OpenStack Networking (Neutron) setup completed.${RESET}"
