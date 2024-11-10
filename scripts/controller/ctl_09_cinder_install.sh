#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to configure the Cinder database
configure_cinder_database() {
    echo "${YELLOW}Configuring Cinder database...${RESET}"
    
    # Connect to MariaDB and create the Cinder database
    mysql << EOF
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';
FLUSH PRIVILEGES;
EOF

    echo "${GREEN}Cinder database configured successfully.${RESET}"
}

# Function to create Cinder service credentials
create_cinder_service_credentials() {
    echo "${YELLOW}Creating Cinder service credentials...${RESET}"

    # Source the admin credentials
    source /root/admin-openrc

    # Create the Cinder user and assign the admin role
    openstack user create --domain default --password $CINDER_PASS cinder
    openstack role add --project service --user cinder admin

    # Create the cinderv3 service entity
    openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3

    echo "${GREEN}Cinder service credentials created successfully.${RESET}"
}

# Function to create the Cinder API endpoints
create_cinder_api_endpoints() {
    echo "${YELLOW}Creating Cinder API endpoints...${RESET}"

    # Create public, internal, and admin endpoints for Cinder
    openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s
    openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s
    openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s

    echo "${GREEN}Cinder API endpoints created successfully.${RESET}"
}

# Function to install and configure Cinder
install_configure_cinder() {
    echo "${YELLOW}Installing and configuring Cinder...${RESET}"
    
    sudo apt install -y cinder-api cinder-scheduler

    local cinder_conf="/etc/cinder/cinder.conf"
    local cinder_conf_bak="/etc/cinder/cinder.conf.bak"
    cp $cinder_conf $cinder_conf_bak
    egrep -v "^#|^$" $cinder_conf_bak > $cinder_conf

    # Configure database connection
    crudini --set "$cinder_conf" "database" "connection" "mysql+pymysql://cinder:$CINDER_DBPASS@controller/cinder"

    # Configure RabbitMQ message queue access
    crudini --set "$cinder_conf" "DEFAULT" "transport_url" "rabbit://openstack:$RABBIT_PASS@controller"

    # Configure Identity service access
    crudini --set "$cinder_conf" "DEFAULT" "auth_strategy" "keystone"
    crudini --set "$cinder_conf" "keystone_authtoken" "www_authenticate_uri" "http://controller:5000"
    crudini --set "$cinder_conf" "keystone_authtoken" "auth_url" "http://controller:5000"
    crudini --set "$cinder_conf" "keystone_authtoken" "memcached_servers" "controller:11211"
    crudini --set "$cinder_conf" "keystone_authtoken" "auth_type" "password"
    crudini --set "$cinder_conf" "keystone_authtoken" "project_domain_name" "Default"
    crudini --set "$cinder_conf" "keystone_authtoken" "user_domain_name" "Default"
    crudini --set "$cinder_conf" "keystone_authtoken" "project_name" "service"
    crudini --set "$cinder_conf" "keystone_authtoken" "username" "cinder"
    crudini --set "$cinder_conf" "keystone_authtoken" "password" "$CINDER_PASS"

    # Configure the my_ip option for the management IP
    crudini --set "$cinder_conf" "DEFAULT" "my_ip" "$CTL_HOSTONLY"

    # Configure lock path for Oslo Concurrency
    crudini --set "$cinder_conf" "oslo_concurrency" "lock_path" "/var/lib/cinder/tmp"

    echo "${GREEN}Cinder configuration updated successfully.${RESET}"
}

# Function to populate the Cinder database
populate_cinder_database() {
    echo "${YELLOW}Populating Cinder database...${RESET}"
    su -s /bin/sh -c "cinder-manage db sync" cinder
    echo "${GREEN}Cinder database populated successfully.${RESET}"
}

# Function to configure Nova to use Cinder
configure_nova_for_cinder() {
    echo "${YELLOW}Configuring Nova to use Cinder...${RESET}"
    
    local nova_conf="/etc/nova/nova.conf"
    crudini --set "$nova_conf" "cinder" "os_region_name" "RegionOne"

    echo "${GREEN}Nova configured to use Cinder successfully.${RESET}"
}

# Function to finalize Cinder installation by restarting services
finalize_cinder_installation() {
    echo "${YELLOW}Finalizing Cinder installation...${RESET}"
    
    sudo service nova-api restart
    sudo service cinder-scheduler restart
    sudo service apache2 restart

    echo "${GREEN}Cinder services restarted successfully.${RESET}"
}

# Run the functions in sequence
configure_cinder_database
create_cinder_service_credentials
create_cinder_api_endpoints
install_configure_cinder
populate_cinder_database
configure_nova_for_cinder
finalize_cinder_installation

echo "${GREEN}OpenStack Block Storage (Cinder) setup completed.${RESET}"
