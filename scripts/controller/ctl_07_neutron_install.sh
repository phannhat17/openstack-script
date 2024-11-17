#!/bin/bash

# Load configuration from config.cfg
source config.cfg

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

    local neutron_conf="/etc/neutron/neutron.conf"
    local neutron_conf_bak="/etc/neutron/neutron.conf.bak"
    cp $neutron_conf $neutron_conf_bak
    egrep -v "^#|^$" $neutron_conf_bak > $neutron_conf

    crudini --set "$neutron_conf" "database" "connection" "mysql+pymysql://neutron:$NEUTRON_DBPASS@controller/neutron"

    crudini --set "$neutron_conf" "DEFAULT" "core_plugin" "ml2"
    crudini --set "$neutron_conf" "DEFAULT" "service_plugins" "router"
    crudini --set "$neutron_conf" "DEFAULT" "transport_url" "rabbit://openstack:$RABBIT_PASS@controller"
    crudini --set "$neutron_conf" "DEFAULT" "auth_strategy" "keystone"
    crudini --set "$neutron_conf" "DEFAULT" "notify_nova_on_port_status_changes" "true"
    crudini --set "$neutron_conf" "DEFAULT" "notify_nova_on_port_data_changes" "true"

    crudini --set "$neutron_conf" "keystone_authtoken" "www_authenticate_uri" "http://controller:5000"
    crudini --set "$neutron_conf" "keystone_authtoken" "auth_url" "http://controller:5000"
    crudini --set "$neutron_conf" "keystone_authtoken" "memcached_servers" "controller:11211"
    crudini --set "$neutron_conf" "keystone_authtoken" "auth_type" "password"
    crudini --set "$neutron_conf" "keystone_authtoken" "project_domain_name" "Default"
    crudini --set "$neutron_conf" "keystone_authtoken" "user_domain_name" "Default"
    crudini --set "$neutron_conf" "keystone_authtoken" "project_name" "service"
    crudini --set "$neutron_conf" "keystone_authtoken" "username" "neutron"
    crudini --set "$neutron_conf" "keystone_authtoken" "password" "$NEUTRON_PASS"

    crudini --set "$neutron_conf" "nova" "auth_url" "http://controller:5000"
    crudini --set "$neutron_conf" "nova" "auth_type" "password"
    crudini --set "$neutron_conf" "nova" "project_domain_name" "Default"
    crudini --set "$neutron_conf" "nova" "user_domain_name" "Default"
    crudini --set "$neutron_conf" "nova" "region_name" "RegionOne"
    crudini --set "$neutron_conf" "nova" "project_name" "service"
    crudini --set "$neutron_conf" "nova" "username" "nova"
    crudini --set "$neutron_conf" "nova" "password" "$NOVA_PASS"

    crudini --set "$neutron_conf" "oslo_concurrency" "lock_path" "/var/lib/neutron/tmp"

    echo "${GREEN}Neutron configuration updated.${RESET}"
}

# Function to configure the Modular Layer 2 (ML2) plugin
configure_ml2_plugin() {
    echo "${YELLOW}Configuring ML2 plugin...${RESET}"
    
    local ml2_conf="/etc/neutron/plugins/ml2/ml2_conf.ini"
    local ml2_conf_bak="/etc/neutron/plugins/ml2/ml2_conf.ini.bak"
    cp $ml2_conf $ml2_conf_bak
    egrep -v "^#|^$" $ml2_conf_bak > $ml2_conf


    crudini --set "$ml2_conf" "ml2" "type_drivers" "flat,vlan,vxlan"
    crudini --set "$ml2_conf" "ml2" "tenant_network_types" "vxlan"
    crudini --set "$ml2_conf" "ml2" "mechanism_drivers" "openvswitch,l2population"
    crudini --set "$ml2_conf" "ml2" "extension_drivers" "port_security"

    crudini --set "$ml2_conf" "ml2_type_flat" "flat_networks" "provider"
    crudini --set "$ml2_conf" "ml2_type_vxlan" "vni_ranges" "1:1000"

    echo "${GREEN}ML2 plugin configuration updated.${RESET}"
}

persist_manual_configuration() {
    echo "${YELLOW}Persisting manual configuration for Open vSwitch...${RESET}"

    cat << EOF | sudo tee /usr/local/bin/setup-bridge.sh > /dev/null
#!/bin/bash

# Flush existing IPs
ip addr flush dev $OS_PROVIDER_INTERFACE_NAME

# Bring up the bridge
ip link set $OS_PROVIDER_BRIDGE_NAME up

# Add IP address to the bridge
ip addr add $CTL_PROVIDER/$NETMASK dev $OS_PROVIDER_BRIDGE_NAME

# Add default route
ip route add default via $GW_PROVIDER
EOF

    sudo chmod +x /usr/local/bin/setup-bridge.sh

    cat << EOF | sudo tee /etc/systemd/system/setup-bridge.service > /dev/null
[Unit]
Description=Set up Open vSwitch bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-bridge.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable setup-bridge.service
    sudo systemctl start setup-bridge.service
    echo "${GREEN}Manual configuration persisted successfully.${RESET}"
}

# Function to configure the Open vSwitch (OVS) agent
configure_openvswitch_agent() {
    echo "${YELLOW}Configuring Open vSwitch (OVS) agent...${RESET}"

    # Enable bridge filter support
    sudo sysctl -w net.ipv4.ip_forward=1

    sudo modprobe br_netfilter
    sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
    sudo sysctl -w net.bridge.bridge-nf-call-arptables=1
    sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1

    # Add IP to OS_PROVIDER_BRIDGE_NAME
    sudo ovs-vsctl add-br $OS_PROVIDER_BRIDGE_NAME
    sudo ovs-vsctl add-port $OS_PROVIDER_BRIDGE_NAME $OS_PROVIDER_INTERFACE_NAME

    
    local openvswitch_agent_conf="/etc/neutron/plugins/ml2/openvswitch_agent.ini"
    local openvswitch_agent_conf_bak="/etc/neutron/plugins/ml2/openvswitch_agent.ini.bak"
    cp $openvswitch_agent_conf $openvswitch_agent_conf_bak
    egrep -v "^#|^$" $openvswitch_agent_conf_bak > $openvswitch_agent_conf

    crudini --set "$openvswitch_agent_conf" "ovs" "bridge_mappings" "provider:$OS_PROVIDER_BRIDGE_NAME"
    crudini --set "$openvswitch_agent_conf" "ovs" "local_ip" "$CTL_MANAGEMENT"

    crudini --set "$openvswitch_agent_conf" "agent" "tunnel_types" "vxlan"
    crudini --set "$openvswitch_agent_conf" "agent" "l2_population" "true"

    crudini --set "$openvswitch_agent_conf" "securitygroup" "enable_security_group" "true"
    crudini --set "$openvswitch_agent_conf" "securitygroup" "firewall_driver" "openvswitch"
    
    persist_manual_configuration
    systemctl restart openvswitch-switch

    echo "${GREEN}Open vSwitch agent configured successfully.${RESET}"    
}

# Function to configure layer-3 (L3) agent
configure_l3_agent() {
    echo "${YELLOW}Configuring L3 agent...${RESET}"
    
    local l3_agent_conf="/etc/neutron/l3_agent.ini"
    local l3_agent_conf_bak="/etc/neutron/l3_agent.ini.bak"
    cp $l3_agent_conf $l3_agent_conf_bak
    egrep -v "^#|^$" $l3_agent_conf_bak > $l3_agent_conf

    crudini --set "$l3_agent_conf" "DEFAULT" "interface_driver" "openvswitch"

    echo "${GREEN}L3 agent configuration updated.${RESET}"
}

# Function to configure DHCP agent
configure_dhcp_agent() {
    echo "${YELLOW}Configuring DHCP agent...${RESET}"
    
    local dhcp_agent_conf="/etc/neutron/dhcp_agent.ini"
    local dhcp_agent_conf_bak="/etc/neutron/dhcp_agent.ini.bak"
    cp $dhcp_agent_conf $dhcp_agent_conf_bak
    egrep -v "^#|^$" $dhcp_agent_conf_bak > $dhcp_agent_conf

    crudini --set "$dhcp_agent_conf" "DEFAULT" "interface_driver" "openvswitch"
    crudini --set "$dhcp_agent_conf" "DEFAULT" "dhcp_driver" "neutron.agent.linux.dhcp.Dnsmasq"
    crudini --set "$dhcp_agent_conf" "DEFAULT" "enable_isolated_metadata" "true"

    echo "${GREEN}DHCP agent configuration updated.${RESET}"
}

# Function to configure the metadata agent
configure_metadata_agent() {
    echo "${YELLOW}Configuring Neutron metadata agent...${RESET}"
    
    local metadata_agent_conf="/etc/neutron/metadata_agent.ini"
    local metadata_agent_conf_bak="/etc/neutron/metadata_agent.ini.bak"
    cp $metadata_agent_conf $metadata_agent_conf_bak
    egrep -v "^#|^$" $metadata_agent_conf_bak > $metadata_agent_conf

    crudini --set "$metadata_agent_conf" "DEFAULT" "nova_metadata_host" "controller"
    crudini --set "$metadata_agent_conf" "DEFAULT" "metadata_proxy_shared_secret" "$METADATA_SECRET"

    echo "${GREEN}Metadata agent configuration updated.${RESET}"
}

# Function to configure Nova to use Neutron
configure_nova_for_neutron() {
    echo "${YELLOW}Configuring Nova to use Neutron...${RESET}"
    
    local file="/etc/nova/nova.conf"
    crudini --set "$file" "neutron" "auth_url" "http://controller:5000"
    crudini --set "$file" "neutron" "auth_type" "password"
    crudini --set "$file" "neutron" "project_domain_name" "Default"
    crudini --set "$file" "neutron" "user_domain_name" "Default"
    crudini --set "$file" "neutron" "region_name" "RegionOne"
    crudini --set "$file" "neutron" "project_name" "service"
    crudini --set "$file" "neutron" "username" "neutron"
    crudini --set "$file" "neutron" "password" "$NEUTRON_PASS"
    crudini --set "$file" "neutron" "service_metadata_proxy" "true"
    crudini --set "$file" "neutron" "metadata_proxy_shared_secret" "$METADATA_SECRET"

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
