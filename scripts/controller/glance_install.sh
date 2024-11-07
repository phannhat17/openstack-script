#!/bin/bash

# Load configuration from config.cfg
source ../config.cfg

# Function to configure the Glance database
configure_glance_database() {
    echo "${YELLOW}Configuring Glance database...${RESET}"
    
    # Connect to MariaDB and create the Glance database
    mysql -u root << EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
FLUSH PRIVILEGES;
EOF

    echo "${GREEN}Glance database configured successfully.${RESET}"
}

# Function to create the Glance user and service credentials
create_glance_user() {
    echo "${YELLOW}Creating Glance user and service credentials...${RESET}"

    # Source admin credentials
    source /root/admin-openrc

    # Create Glance user
    openstack user create --domain default --password $GLANCE_PASS glance

    # Add the admin role to the Glance user
    openstack role add --project service --user glance admin

    # Create the Glance service entity
    openstack service create --name glance --description "OpenStack Image" image

    echo "${GREEN}Glance user and service credentials created successfully.${RESET}"
}

# Function to create Glance API endpoints and retrieve the endpoint_id
create_glance_endpoints() {
    echo "${YELLOW}Creating Glance API endpoints...${RESET}"

    # Create public, internal, and admin endpoints for Glance
    public_endpoint=$(openstack endpoint create --region RegionOne image public http://controller:9292 -f value -c id)
    internal_endpoint=$(openstack endpoint create --region RegionOne image internal http://controller:9292 -f value -c id)
    admin_endpoint=$(openstack endpoint create --region RegionOne image admin http://controller:9292 -f value -c id)

    echo "${GREEN}Glance API endpoints created successfully with endpoint IDs:${RESET}"
    echo "${GREEN}Public Endpoint ID: $public_endpoint${RESET}"
    echo "${GREEN}Internal Endpoint ID: $internal_endpoint${RESET}"
    echo "${GREEN}Admin Endpoint ID: $admin_endpoint${RESET}"

    # Save public endpoint ID for later use in configuration
    export GLANCE_ENDPOINT_ID=$public_endpoint
}


# Function to install and configure Glance
install_configure_glance() {
    echo "${YELLOW}Installing and configuring Glance...${RESET}"
    
    # Install Glance package
    sudo apt install -y glance

    # Configure Glance in /etc/glance/glance-api.conf
    sudo tee /etc/glance/glance-api.conf > /dev/null << EOF
[database]
connection = mysql+pymysql://glance:$GLANCE_DBPASS@controller/glance

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = $GLANCE_PASS

[paste_deploy]
flavor = keystone

[glance_store]
default_backend = fs
filesystem_store_datadir = /var/lib/glance/images/

[DEFAULT]
enabled_backends = fs:file

[oslo_limit]
auth_url = http://controller:5000
auth_type = password
user_domain_id = default
username = glance
system_scope = all
password = $GLANCE_PASS
endpoint_id = $GLANCE_ENDPOINT_ID
region_name = RegionOne
EOF

    echo "${GREEN}Glance configuration updated.${RESET}"
}

# Function to populate the Glance database
populate_glance_database() {
    echo "${YELLOW}Populating Glance database...${RESET}"
    su -s /bin/sh -c "glance-manage db_sync" glance
    echo "${GREEN}Glance database populated successfully.${RESET}"
}

# Function to finalize the Glance installation
finalize_glance_installation() {
    echo "${YELLOW}Finalizing Glance installation...${RESET}"

    # Restart the Glance API service
    sudo service glance-api restart

    echo "${GREEN}Glance installation and configuration completed successfully.${RESET}"
}

# Run the functions in sequence
configure_glance_database
create_glance_user
create_glance_endpoints
install_configure_glance
populate_glance_database
finalize_glance_installation

echo "${GREEN}OpenStack Image Service (Glance) setup completed.${RESET}"
