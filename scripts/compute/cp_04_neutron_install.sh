#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to install the Neutron Open vSwitch agent
install_neutron_openvswitch_agent() {
    echo "${YELLOW}Installing Neutron Open vSwitch agent...${RESET}"
    sudo apt install -y neutron-openvswitch-agent
    echo "${GREEN}Neutron Open vSwitch agent installed successfully.${RESET}"
}

# Function to configure neutron.conf
configure_neutron_conf() {
    local neutron_conf="/etc/neutron/neutron.conf"
    local neutron_conf_bak="/etc/neutron/neutron.conf.bak"
    
    # Backup and clean up neutron.conf
    echo "${YELLOW}Configuring $neutron_conf...${RESET}"
    cp $neutron_conf $neutron_conf_bak
    egrep -v "^#|^$" $neutron_conf_bak > $neutron_conf

    # [database] section - comment out connection option
    sudo sed -i "/^\[database\]/,/^\[/ s/^connection/#connection/" $neutron_conf

    # [DEFAULT] section - configure RabbitMQ message queue access
    crudini --set "$neutron_conf" "DEFAULT" "transport_url" "rabbit://openstack:$RABBIT_PASS@controller"

    # [oslo_concurrency] section - configure lock path
    crudini --set "$neutron_conf" "oslo_concurrency" "lock_path" "/var/lib/neutron/tmp"

    echo "${GREEN}Neutron configuration updated in $neutron_conf.${RESET}"
}

# Function to configure the Open vSwitch agent
configure_openvswitch_agent() {
    local ovs_agent_conf="/etc/neutron/plugins/ml2/openvswitch_agent.ini"
    local ovs_agent_conf_bak="/etc/neutron/plugins/ml2/openvswitch_agent.ini.bak"
    
    # Backup and configure openvswitch_agent.ini
    echo "${YELLOW}Configuring $ovs_agent_conf...${RESET}"
    cp $ovs_agent_conf $ovs_agent_conf_bak
    egrep -v "^#|^$" $ovs_agent_conf_bak > $ovs_agent_conf

    # [ovs] section - map provider network and configure overlay IP
    crudini --set "$ovs_agent_conf" "ovs" "bridge_mappings" "provider:$PROVIDER_BRIDGE_NAME"
    crudini --set "$ovs_agent_conf" "ovs" "local_ip" "$COM_MANAGEMENT"

    # Ensure the provider bridge is created and add the provider interface to the bridge
    echo "${YELLOW}Creating provider bridge and adding interface...${RESET}"
    sudo ovs-vsctl add-br $OS_PROVIDER_BRIDGE_NAME
    sudo ovs-vsctl add-port $OS_PROVIDER_BRIDGE_NAME $OS_PROVIDER_INTERFACE_NAME

    # [agent] section - enable VXLAN and layer-2 population
    crudini --set "$ovs_agent_conf" "agent" "tunnel_types" "vxlan"
    crudini --set "$ovs_agent_conf" "agent" "l2_population" "true"

    # [securitygroup] section - enable security groups and set firewall driver
    crudini --set "$ovs_agent_conf" "securitygroup" "enable_security_group" "true"
    crudini --set "$ovs_agent_conf" "securitygroup" "firewall_driver" "openvswitch"

    echo "${GREEN}Open vSwitch agent configuration completed.${RESET}"
}

# Function to enable bridge networking support for the hybrid iptables firewall driver (if required)
enable_bridge_networking() {
    echo "${YELLOW}Enabling bridge networking support for hybrid iptables firewall...${RESET}"

    # Load the br_netfilter kernel module
    sudo modprobe br_netfilter

    # Enable bridge filtering for iptables
    sudo tee /etc/sysctl.d/99-sysctl.conf > /dev/null << EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF

    # Apply the changes
    sudo sysctl --system
    echo "${GREEN}Bridge networking support enabled.${RESET}"
}

# Function to configure nova.conf to use Neutron
configure_nova_conf_for_neutron() {
    local nova_conf="/etc/nova/nova.conf"
    
    echo "${YELLOW}Configuring $nova_conf for Neutron access...${RESET}"

    # [neutron] section - configure access parameters
    crudini --set "$nova_conf" "neutron" "auth_url" "http://controller:5000"
    crudini --set "$nova_conf" "neutron" "auth_type" "password"
    crudini --set "$nova_conf" "neutron" "project_domain_name" "Default"
    crudini --set "$nova_conf" "neutron" "user_domain_name" "Default"
    crudini --set "$nova_conf" "neutron" "region_name" "RegionOne"
    crudini --set "$nova_conf" "neutron" "project_name" "service"
    crudini --set "$nova_conf" "neutron" "username" "neutron"
    crudini --set "$nova_conf" "neutron" "password" "$NEUTRON_PASS"

    echo "${GREEN}Nova configured to use Neutron successfully.${RESET}"
}

# Function to restart relevant services
restart_services() {
    echo "${YELLOW}Restarting Nova Compute and Neutron Open vSwitch agent services...${RESET}"
    sudo service nova-compute restart
    sudo service neutron-openvswitch-agent restart
    echo "${GREEN}Services restarted successfully.${RESET}"
}

# Run all functions in sequence
install_neutron_openvswitch_agent
configure_neutron_conf

configure_openvswitch_agent
enable_bridge_networking

configure_nova_conf_for_neutron
restart_services

echo "${GREEN}OpenStack Networking (Neutron) setup on compute node completed.${RESET}"
