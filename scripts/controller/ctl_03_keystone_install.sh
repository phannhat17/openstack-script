#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to create admin-openrc and demo-openrc files in /root/
create_openrc_files() {
    echo "${YELLOW}Creating admin-openrc and demo-openrc files in /root/...${RESET}"

    # Admin OpenRC
    sudo tee /root/admin-openrc > /dev/null << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

    # Demo OpenRC
    sudo tee /root/demo-openrc > /dev/null << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=myproject
export OS_USERNAME=myuser
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

    echo "${GREEN}OpenRC files created successfully in /root/.${RESET}"
}

# Function to configure MariaDB for Keystone
configure_keystone_database() {
    echo "${YELLOW}Configuring Keystone database...${RESET}"
    
    # Connect to MariaDB and create the Keystone database
    mysql << EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
FLUSH PRIVILEGES;
EOF

    echo "${GREEN}Keystone database configured successfully.${RESET}"
}

# Function to install and configure Keystone
install_configure_keystone() {
    echo "${YELLOW}Installing Keystone...${RESET}"
    sudo apt update
    sudo apt install -y keystone

    # Configure Keystone
    local keystone_config="/etc/keystone/keystone.conf"
    local keystone_config_bak="/etc/keystone/keystone.conf.bak"
    cp $keystone_config $keystone_config_bak
    egrep -v "^#|^$" $keystone_config_bak > $keystone_config

    echo "${YELLOW}Configuring $keystone_config...${RESET}"
    crudini --set "$keystone_config" "database" "connection" "mysql+pymysql://keystone:$KEYSTONE_DBPASS@controller/keystone"
    crudini --set "$keystone_config" "token" "provider" "fernet"

    echo "${GREEN}Keystone configuration updated.${RESET}"
}

# Function to populate Keystone database
populate_keystone_database() {
    echo "${YELLOW}Populating Keystone database...${RESET}"
    su -s /bin/sh -c "keystone-manage db_sync" keystone
    echo "${GREEN}Keystone database populated successfully.${RESET}"
}

# Function to initialize Fernet key repositories
initialize_fernet_keys() {
    echo "${YELLOW}Initializing Fernet key repositories...${RESET}"
    sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
    echo "${GREEN}Fernet key repositories initialized successfully.${RESET}"
}

# Function to bootstrap the Keystone service
bootstrap_keystone_service() {
    echo "${YELLOW}Bootstrapping Keystone service...${RESET}"
    sudo keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
        --bootstrap-admin-url http://controller:5000/v3/ \
        --bootstrap-internal-url http://controller:5000/v3/ \
        --bootstrap-public-url http://controller:5000/v3/ \
        --bootstrap-region-id RegionOne
    echo "${GREEN}Keystone service bootstrapped successfully.${RESET}"
}

# Function to configure Apache for Keystone
configure_apache() {
    echo "${YELLOW}Configuring Apache HTTP server for Keystone...${RESET}"
    
    # Update ServerName in Apache configuration
    if ! grep -q "ServerName controller" /etc/apache2/apache2.conf; then
        echo "ServerName controller" | sudo tee -a /etc/apache2/apache2.conf
    fi

    # Restart Apache to apply changes
    sudo service apache2 restart
    echo "${GREEN}Apache configured and restarted successfully.${RESET}"
}

# Function to set up environment variables for administrative user
setup_admin_env_vars() {
    echo "${YELLOW}Setting up environment variables for administrative user...${RESET}"
    source /root/admin-openrc
    echo "${GREEN}Environment variables set successfully.${RESET}"
}

# Function to create domain, projects, users, and roles
create_domain_projects_users_roles() {
    echo "${YELLOW}Creating domain, projects, users, and roles...${RESET}"
    
    # Source the admin credentials
    source /root/admin-openrc

    # Create a new domain
    openstack domain create --description "An Example Domain" example
    echo "${GREEN}Domain 'example' created.${RESET}"

    # Create the service project
    openstack project create --domain default --description "Service Project" service
    echo "${GREEN}Project 'service' created.${RESET}"

    # Create the demo project
    openstack project create --domain default --description "Demo Project" myproject
    echo "${GREEN}Project 'myproject' created.${RESET}"

    # Create the myuser user and prompt for the password
    openstack user create --domain default --password $DEMO_PASS myuser
    echo "${GREEN}User 'myuser' created.${RESET}"

    # Create the myrole role
    openstack role create myrole
    echo "${GREEN}Role 'myrole' created.${RESET}"

    # Add the myrole role to the myproject project and myuser user
    openstack role add --project myproject --user myuser myrole
    echo "${GREEN}Role 'myrole' assigned to user 'myuser' in project 'myproject'.${RESET}"
}


# Run the functions in sequence
create_openrc_files
configure_keystone_database
install_configure_keystone
populate_keystone_database
initialize_fernet_keys
bootstrap_keystone_service
configure_apache
setup_admin_env_vars
create_domain_projects_users_roles 

echo "${GREEN}OpenStack Identity (Keystone) setup completed.${RESET}"
