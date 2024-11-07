#!/bin/bash

# Load configuration from config.cfg
source ../config.cfg


# Function to add OpenStack repository
add_repo() {
    echo "${YELLOW}Adding OpenStack Caracal repository...${RESET}"
    sudo add-apt-repository cloud-archive:caracal -y
    sudo apt update
    echo "${GREEN}Repository added successfully.${RESET}"
}

# Function to configure SQL database (MariaDB)
config_sql_database() {
    echo "${YELLOW}Installing and configuring MariaDB...${RESET}"
    sudo apt install -y mariadb-server python3-pymysql

    # Configure MariaDB
    sudo tee /etc/mysql/mariadb.conf.d/99-openstack.cnf > /dev/null << EOF
[mysqld]
bind-address = $CTL_HOSTONLY
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF

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

    # Configure Etcd
    sudo tee /etc/default/etcd > /dev/null << EOF
ETCD_NAME="controller"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER="controller=http://$CTL_HOSTONLY:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$CTL_HOSTONLY:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://$CTL_HOSTONLY:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="http://$CTL_HOSTONLY:2379"
EOF

    # Enable and restart Etcd
    sudo systemctl enable etcd
    sudo systemctl restart etcd
    echo "${GREEN}Etcd configured successfully.${RESET}"
}

# Run the functions in sequence
# add_repo - Uncomment to add OpenStack repository
config_sql_database
config_message_queue
config_memcached
config_etcd

echo "${GREEN}All components installed and configured.${RESET}"
