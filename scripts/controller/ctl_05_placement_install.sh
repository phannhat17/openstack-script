#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to configure the Placement database
configure_placement_database() {
    echo "${YELLOW}Configuring Placement database...${RESET}"
    
    # Connect to MariaDB and create the Placement database
    mysql -u root << EOF
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '$PLACEMENT_DBPASS';
FLUSH PRIVILEGES;
EOF

    echo "${GREEN}Placement database configured successfully.${RESET}"
}

# Function to create the Placement user and service credentials
create_placement_user() {
    echo "${YELLOW}Creating Placement user and service credentials...${RESET}"

    # Source admin credentials
    source /root/admin-openrc

    # Create Placement user
    openstack user create --domain default --password $PLACEMENT_PASS placement

    # Add the Placement user to the service project with the admin role
    openstack role add --project service --user placement admin

    # Create the Placement service entity
    openstack service create --name placement --description "Placement API" placement

    echo "${GREEN}Placement user and service credentials created successfully.${RESET}"
}

# Function to create Placement API endpoints
create_placement_endpoints() {
    echo "${YELLOW}Creating Placement API endpoints...${RESET}"

    # Create public, internal, and admin endpoints for Placement
    openstack endpoint create --region RegionOne placement public http://controller:8778
    openstack endpoint create --region RegionOne placement internal http://controller:8778
    openstack endpoint create --region RegionOne placement admin http://controller:8778

    echo "${GREEN}Placement API endpoints created successfully.${RESET}"
}

# Function to install and configure Placement
install_configure_placement() {
    echo "${YELLOW}Installing and configuring Placement...${RESET}"
    
    # Install Placement package
    sudo apt install -y placement-api

    # Configure Placement in /etc/placement/placement.conf
    local placement_conf="/etc/placement/placement.conf"
    local placement_conf_bak="/etc/placement/placement.conf.bak"
    cp $placement_conf $placement_conf_bak
    egrep -v "^#|^$" $placement_conf_bak > $placement_conf

    crudini --set "$placement_conf" "placement_database" "connection" "mysql+pymysql://placement:$PLACEMENT_DBPASS@controller/placement"

    crudini --set "$placement_conf" "api" "auth_strategy" "keystone"

    crudini --set "$placement_conf" "keystone_authtoken" "auth_url" "http://controller:5000/v3"
    crudini --set "$placement_conf" "keystone_authtoken" "memcached_servers" "controller:11211"
    crudini --set "$placement_conf" "keystone_authtoken" "auth_type" "password"
    crudini --set "$placement_conf" "keystone_authtoken" "project_domain_name" "Default"
    crudini --set "$placement_conf" "keystone_authtoken" "user_domain_name" "Default"
    crudini --set "$placement_conf" "keystone_authtoken" "project_name" "service"
    crudini --set "$placement_conf" "keystone_authtoken" "username" "placement"
    crudini --set "$placement_conf" "keystone_authtoken" "password" "$PLACEMENT_PASS"

    # Comment out any other options in [keystone_authtoken]
    local allowed_keys=("auth_url" "memcached_servers" "auth_type" "project_domain_name" "user_domain_name" "project_name" "username" "password")
    sed -i "/^\[keystone_authtoken\]/,/^\[/{ 
        /^\[keystone_authtoken\]/!{/^\[/!s/^\([^#].*\)/#\1/}
    }" "$placement_conf"

    # Uncomment required keys to ensure they remain active
    for key in "${allowed_keys[@]}"; do
        sed -i "/^\[keystone_authtoken\]/,/^\[/s/^#\($key[ ]*=.*\)/\1/" "$placement_conf"
    done


    echo "${GREEN}Placement configuration updated.${RESET}"
}

# Function to populate the Placement database
populate_placement_database() {
    echo "${YELLOW}Populating Placement database...${RESET}"
    su -s /bin/sh -c "placement-manage db sync" placement
    echo "${GREEN}Placement database populated successfully.${RESET}"
}

# Function to finalize Placement installation
finalize_placement_installation() {
    echo "${YELLOW}Finalizing Placement installation...${RESET}"

    # Restart the Apache service
    sudo service apache2 restart

    echo "${GREEN}Placement service setup completed successfully.${RESET}"
}

# Run the functions in sequence
configure_placement_database
create_placement_user
create_placement_endpoints
install_configure_placement
populate_placement_database
finalize_placement_installation

echo "${GREEN}OpenStack Placement service setup completed.${RESET}"
