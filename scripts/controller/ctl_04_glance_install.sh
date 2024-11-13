#!/bin/bash
set -e

# Load configuration from config.cfg
source config.cfg

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

    # Make sure that the glance account has reader access to system-scope resources
    openstack role add --user glance --user-domain Default --system all reader

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
    local glance_conf="/etc/glance/glance-api.conf"
    local glance_conf_bak="/etc/glance/glance-api.conf.bak"
    cp $glance_conf $glance_conf_bak
    egrep -v "^#|^$" $glance_conf_bak > $glance_conf

    crudini --set "$glance_conf" "database" "connection" "mysql+pymysql://glance:$GLANCE_DBPASS@controller/glance"

    crudini --set "$glance_conf" "keystone_authtoken" "www_authenticate_uri" "http://controller:5000"
    crudini --set "$glance_conf" "keystone_authtoken" "auth_url" "http://controller:5000"
    crudini --set "$glance_conf" "keystone_authtoken" "memcached_servers" "controller:11211"
    crudini --set "$glance_conf" "keystone_authtoken" "auth_type" "password"
    crudini --set "$glance_conf" "keystone_authtoken" "project_domain_name" "Default"
    crudini --set "$glance_conf" "keystone_authtoken" "user_domain_name" "Default"
    crudini --set "$glance_conf" "keystone_authtoken" "project_name" "service"
    crudini --set "$glance_conf" "keystone_authtoken" "username" "glance"
    crudini --set "$glance_conf" "keystone_authtoken" "password" "$GLANCE_PASS"

    crudini --set "$glance_conf" "paste_deploy" "flavor" "keystone"

    crudini --set "$glance_conf" "DEFAULT" "enabled_backends" "fs:file"

    crudini --set "$glance_conf" "glance_store" "default_backend" "fs"

    crudini --set "$glance_conf" "fs" "filesystem_store_datadir" "/var/lib/glance/images/"

    crudini --set "$glance_conf" "oslo_limit" "auth_url" "http://controller:5000"
    crudini --set "$glance_conf" "oslo_limit" "auth_type" "password"
    crudini --set "$glance_conf" "oslo_limit" "user_domain_id" "default"
    crudini --set "$glance_conf" "oslo_limit" "username" "glance"
    crudini --set "$glance_conf" "oslo_limit" "system_scope" "all"
    crudini --set "$glance_conf" "oslo_limit" "password" "$GLANCE_PASS"
    crudini --set "$glance_conf" "oslo_limit" "endpoint_id" "$GLANCE_ENDPOINT_ID"
    crudini --set "$glance_conf" "oslo_limit" "region_name" "RegionOne"

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


verify_glance () {
    echo "${YELLOW}Verifying Glance...${RESET}"

	source /root/admin-openrc

	apt-get install wget -y
	wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img

    glance image-create --name "cirros" \
    --file cirros-0.4.0-x86_64-disk.img \
    --disk-format qcow2 --container-format bare \
    --visibility=public
	  
    # Check if glance image-list contains the expected "active" status for "cirros"
    if glance image-list | grep -q 'cirros.*active'; then
        echo "${GREEN}Glance is ready to work.${RESET}"
    else
        echo "${RED}Glance image verification failed. Exiting.${RESET}"
        exit 1
    fi
}


# Run the functions in sequence
configure_glance_database
create_glance_user
create_glance_endpoints
install_configure_glance
populate_glance_database
finalize_glance_installation
verify_glance

echo "${GREEN}OpenStack Image Service (Glance) setup completed.${RESET}"
