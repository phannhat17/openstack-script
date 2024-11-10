#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function update and upgrade for CONTROLLER
update_upgrade () {
    echo "${YELLOW}Update and Update controller...${RESET}"
	apt-get update -y&& apt-get upgrade -y
    echo "${GREEN}Update and Update controller successfully.${RESET}"
}

# Function to add OpenStack repository
add_repo() {
    echo "${YELLOW}Adding OpenStack Caracal repository...${RESET}"
    sudo add-apt-repository cloud-archive:caracal -y
    echo "${GREEN}Repository added successfully.${RESET}"
}

# Function to install crudini
install_crudini() {
    echo "${YELLOW}Installing crudini...${RESET}"
    sudo apt install -y crudini
    echo "${GREEN}crudini installed successfully.${RESET}"
}

# Function to install OpenStack client package
install_ops_packages() {
    echo "${YELLOW}Installing OpenStack client...${RESET}"
    sudo apt-get install python3-openstackclient -y
    echo "${GREEN}OpenStack client installed successfully.${RESET}"
}

# Function to configure SQL database (MariaDB)
config_sql_database() {
    echo "${YELLOW}Installing and configuring MariaDB...${RESET}"
    sudo apt install -y mariadb-server python3-pymysql

    local mariadb_conf="/etc/mysql/mariadb.conf.d/99-openstack.cnf"
    crudini --set "$mariadb_conf" "mysqld" "bind-address" "$CTL_HOSTONLY"
    crudini --set "$mariadb_conf" "mysqld" "default-storage-engine" "innodb"
    crudini --set "$mariadb_conf" "mysqld" "innodb_file_per_table" "on"
    crudini --set "$mariadb_conf" "mysqld" "max_connections" "4096"
    crudini --set "$mariadb_conf" "mysqld" "collation-server" "utf8_general_ci"
    crudini --set "$mariadb_conf" "mysqld" "character-set-server" "utf8"

    # Restart and secure MariaDB
    echo "${YELLOW}Restarting MariaDB...${RESET}"
    sudo service mysql restart
    echo "${YELLOW}Securing MariaDB...${RESET}"
    sudo mysql_secure_installation
    echo "${GREEN}MariaDB configured successfully.${RESET}"
}

# Function to configure RabbitMQ (Message Queue)
config_message_queue() {
    echo "${YELLOW}Installing and configuring RabbitMQ...${RESET}"
    sudo apt install -y rabbitmq-server

    # Configure RabbitMQ
    sudo rabbitmqctl add_user openstack $RABBIT_PASS
    sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"
    echo "${GREEN}RabbitMQ configured successfully.${RESET}"
}

# Function to configure Memcached
config_memcached() {
    echo "${YELLOW}Installing and configuring Memcached...${RESET}"
    sudo apt install -y memcached python3-memcache

    # Configure Memcached
    sudo sed -i "s/^-l 127.0.0.1/-l $CTL_HOSTONLY/" /etc/memcached.conf

    # Restart Memcached
    sudo service memcached restart
    echo "${GREEN}Memcached configured successfully.${RESET}"
}

# Function to configure Etcd
config_etcd() {
    echo "${YELLOW}Installing and configuring Etcd...${RESET}"
    sudo apt install -y etcd

    # Update /etc/default/etcd with required Etcd configuration
    local etcd_config="/etc/default/etcd"
    local etcd_config_bak="/etc/default/etcd.bak"
    cp $etcd_config $etcd_config_bak
    egrep -v "^#|^$" $etcd_config_bak > $etcd_config

    crudini --set "$etcd_config" "" "ETCD_NAME" "\"controller\""
    crudini --set "$etcd_config" "" "ETCD_DATA_DIR" "\"/var/lib/etcd\""
    crudini --set "$etcd_config" "" "ETCD_INITIAL_CLUSTER_STATE" "\"new\""
    crudini --set "$etcd_config" "" "ETCD_INITIAL_CLUSTER_TOKEN" "\"etcd-cluster-01\""
    crudini --set "$etcd_config" "" "ETCD_INITIAL_CLUSTER" "\"controller=http://$CTL_HOSTONLY:2380\""
    crudini --set "$etcd_config" "" "ETCD_INITIAL_ADVERTISE_PEER_URLS" "\"http://$CTL_HOSTONLY:2380\""
    crudini --set "$etcd_config" "" "ETCD_ADVERTISE_CLIENT_URLS" "\"http://$CTL_HOSTONLY:2379\""
    crudini --set "$etcd_config" "" "ETCD_LISTEN_PEER_URLS" "\"http://0.0.0.0:2380\""
    crudini --set "$etcd_config" "" "ETCD_LISTEN_CLIENT_URLS" "\"http://$CTL_HOSTONLY:2379\""

    # Enable and restart Etcd
    sudo systemctl enable etcd
    sudo systemctl restart etcd
    echo "${GREEN}Etcd configured successfully.${RESET}"
}

# Function to install and configure Chrony NTP service
config_ntp_service() {
    echo "${YELLOW}Installing and configuring Chrony...${RESET}"
    
    # Install Chrony
    sudo apt install -y chrony

    # Configure Chrony
    local chrony_conf="/etc/chrony/chrony.conf"
    echo "allow 10.0.0.0/24" >> $chrony_conf

    # Restart Chrony service
    sudo service chrony restart
    echo "${GREEN}Chrony configured successfully.${RESET}"
}

# Run the functions in sequence
update_upgrade
add_repo
install_crudini
install_ops_packages
config_ntp_service
config_sql_database
config_message_queue
config_memcached
config_etcd

echo "${GREEN}All components installed and configured.${RESET}"
