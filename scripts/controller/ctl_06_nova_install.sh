#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to configure the Nova databases
configure_nova_databases() {
    echo "${YELLOW}Configuring Nova databases...${RESET}"
    
    mysql -u root << EOF
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
FLUSH PRIVILEGES;
EOF

    echo "${GREEN}Nova databases configured successfully.${RESET}"
}

# Function to create the Nova user and service credentials
create_nova_user() {
    echo "${YELLOW}Creating Nova user and service credentials...${RESET}"

    # Source admin credentials
    source /root/admin-openrc

    # Create Nova user
    openstack user create --domain default --password $NOVA_PASS nova

    # Add the admin role to the Nova user in the service project
    openstack role add --project service --user nova admin

    # Create the Nova service entity
    openstack service create --name nova --description "OpenStack Compute" compute

    echo "${GREEN}Nova user and service credentials created successfully.${RESET}"
}

# Function to create Nova API endpoints
create_nova_endpoints() {
    echo "${YELLOW}Creating Nova API endpoints...${RESET}"

    openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
    openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
    openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1

    echo "${GREEN}Nova API endpoints created successfully.${RESET}"
}

# Function to install and configure Nova
install_configure_nova() {
    echo "${YELLOW}Installing and configuring Nova...${RESET}"
    
    sudo apt install -y nova-api nova-conductor nova-novncproxy nova-scheduler

    local nova_conf="/etc/nova/nova.conf"
    local nova_conf_bak="/etc/nova/nova.conf.bak"
    cp $nova_conf $nova_conf_bak
    egrep -v "^#|^$" $nova_conf_bak > $nova_conf

    crudini --set "$nova_conf" "api_database" "connection" "mysql+pymysql://nova:$NOVA_DBPASS@controller/nova_api"

    crudini --set "$nova_conf" "database" "connection" "mysql+pymysql://nova:$NOVA_DBPASS@controller/nova"

    crudini --set "$nova_conf" "DEFAULT" "transport_url" "rabbit://openstack:$RABBIT_PASS@controller:5672/"
    crudini --set "$nova_conf" "DEFAULT" "my_ip" "$CTL_MANAGEMENT"

    crudini --set "$nova_conf" "api" "auth_strategy" "keystone"

    crudini --set "$nova_conf" "keystone_authtoken" "www_authenticate_uri" "http://controller:5000/"
    crudini --set "$nova_conf" "keystone_authtoken" "auth_url" "http://controller:5000/"
    crudini --set "$nova_conf" "keystone_authtoken" "memcached_servers" "controller:11211"
    crudini --set "$nova_conf" "keystone_authtoken" "auth_type" "password"
    crudini --set "$nova_conf" "keystone_authtoken" "project_domain_name" "Default"
    crudini --set "$nova_conf" "keystone_authtoken" "user_domain_name" "Default"
    crudini --set "$nova_conf" "keystone_authtoken" "project_name" "service"
    crudini --set "$nova_conf" "keystone_authtoken" "username" "nova"
    crudini --set "$nova_conf" "keystone_authtoken" "password" "$NOVA_PASS"

    crudini --set "$nova_conf" "service_user" "send_service_user_token" "true"
    crudini --set "$nova_conf" "service_user" "auth_url" "http://controller:5000/v3"
    crudini --set "$nova_conf" "service_user" "auth_strategy" "keystone"
    crudini --set "$nova_conf" "service_user" "auth_type" "password"
    crudini --set "$nova_conf" "service_user" "project_domain_name" "Default"
    crudini --set "$nova_conf" "service_user" "project_name" "service"
    crudini --set "$nova_conf" "service_user" "user_domain_name" "Default"
    crudini --set "$nova_conf" "service_user" "username" "nova"
    crudini --set "$nova_conf" "service_user" "password" "$NOVA_PASS"

    crudini --set "$nova_conf" "vnc" "enabled" "true"
    crudini --set "$nova_conf" "vnc" "server_listen" "\$my_ip"
    crudini --set "$nova_conf" "vnc" "server_proxyclient_address" "\$my_ip"

    crudini --set "$nova_conf" "glance" "api_servers" "http://controller:9292"

    crudini --set "$nova_conf" "oslo_concurrency" "lock_path" "/var/lib/nova/tmp"
    
    crudini --set "$nova_conf" "placement" "region_name" "RegionOne"
    crudini --set "$nova_conf" "placement" "project_domain_name" "Default"
    crudini --set "$nova_conf" "placement" "project_name" "service"
    crudini --set "$nova_conf" "placement" "auth_type" "password"
    crudini --set "$nova_conf" "placement" "user_domain_name" "Default"
    crudini --set "$nova_conf" "placement" "auth_url" "http://controller:5000/v3"
    crudini --set "$nova_conf" "placement" "username" "placement"
    crudini --set "$nova_conf" "placement" "password" "$PLACEMENT_PASS"

    echo "${GREEN}Nova configuration updated.${RESET}"
}

# Function to populate the Nova API database
populate_nova_api_database() {
    echo "${YELLOW}Populating Nova API database...${RESET}"
    su -s /bin/sh -c "nova-manage api_db sync" nova
    echo "${GREEN}Nova API database populated successfully.${RESET}"
}

# Function to register cell0 and create cell1
register_cells() {
    echo "${YELLOW}Registering cell0 and creating cell1...${RESET}"
    su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
    su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
    echo "${GREEN}cell0 registered and cell1 created successfully.${RESET}"
}

# Function to populate the Nova database
populate_nova_database() {
    echo "${YELLOW}Populating Nova database...${RESET}"
    su -s /bin/sh -c "nova-manage db sync" nova
    echo "${GREEN}Nova database populated successfully.${RESET}"
}

# Function to verify cells registration
verify_cells() {
    echo "${YELLOW}Verifying cell0 and cell1 registration...${RESET}"
    su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
}

# Function to finalize Nova installation
finalize_nova_installation() {
    echo "${YELLOW}Finalizing Nova installation...${RESET}"

    sudo service nova-api restart
    sudo service nova-scheduler restart
    sudo service nova-conductor restart
    sudo service nova-novncproxy restart

    echo "${GREEN}Nova services restarted successfully.${RESET}"
}

# Run the functions in sequence
configure_nova_databases
create_nova_user
create_nova_endpoints
install_configure_nova
populate_nova_api_database
register_cells
populate_nova_database
verify_cells
finalize_nova_installation

echo "${GREEN}OpenStack Compute (Nova) setup completed.${RESET}"
