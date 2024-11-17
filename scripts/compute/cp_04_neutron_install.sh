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

persist_manual_configuration() {
    echo "${YELLOW}Persisting manual configuration for Open vSwitch...${RESET}"

    cat << EOF | sudo tee /usr/local/bin/setup-bridge.sh > /dev/null
#!/bin/bash

# Flush existing IPs
ip addr flush dev $OS_PROVIDER_INTERFACE_NAME

# Bring up the bridge
ip link set $OS_PROVIDER_BRIDGE_NAME up

# Add IP address to the bridge
ip addr add $COM_PROVIDER/$NETMASK dev $OS_PROVIDER_BRIDGE_NAME

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


# Function to configure the Open vSwitch agent
configure_openvswitch_agent() {
    local ovs_agent_conf="/etc/neutron/plugins/ml2/openvswitch_agent.ini"
    local ovs_agent_conf_bak="/etc/neutron/plugins/ml2/openvswitch_agent.ini.bak"
    
    # Backup and configure openvswitch_agent.ini
    echo "${YELLOW}Configuring $ovs_agent_conf...${RESET}"
    cp $ovs_agent_conf $ovs_agent_conf_bak
    egrep -v "^#|^$" $ovs_agent_conf_bak > $ovs_agent_conf

    # Enable bridge filter support
    sudo sysctl -w net.ipv4.ip_forward=1

    sudo modprobe br_netfilter
    sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
    sudo sysctl -w net.bridge.bridge-nf-call-arptables=1
    sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1

    # Ensure the provider bridge is created and add the provider interface to the bridge
    echo "${YELLOW}Creating provider bridge and adding interface...${RESET}"
    sudo ovs-vsctl add-br $OS_PROVIDER_BRIDGE_NAME
    sudo ovs-vsctl add-port $OS_PROVIDER_BRIDGE_NAME $OS_PROVIDER_INTERFACE_NAME


    # [ovs] section - map provider network and configure overlay IP
    crudini --set "$ovs_agent_conf" "ovs" "bridge_mappings" "provider:$OS_PROVIDER_BRIDGE_NAME"
    crudini --set "$ovs_agent_conf" "ovs" "local_ip" "$COM_MANAGEMENT"

    # [agent] section - enable VXLAN and layer-2 population
    crudini --set "$ovs_agent_conf" "agent" "tunnel_types" "vxlan"
    crudini --set "$ovs_agent_conf" "agent" "l2_population" "true"

    # [securitygroup] section - enable security groups and set firewall driver
    crudini --set "$ovs_agent_conf" "securitygroup" "enable_security_group" "true"
    crudini --set "$ovs_agent_conf" "securitygroup" "firewall_driver" "openvswitch"

    persist_manual_configuration
    systemctl restart openvswitch-switch

    echo "${GREEN}Open vSwitch agent configuration completed.${RESET}"
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

configure_nova_conf_for_neutron
restart_services

echo "${GREEN}OpenStack Networking (Neutron) setup on compute node completed.${RESET}"
