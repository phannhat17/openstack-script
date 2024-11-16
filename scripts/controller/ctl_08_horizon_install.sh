#!/bin/bash

# Load configuration from config.cfg
source config.cfg

OPENSTACK_HOST="controller"
ALLOWED_HOSTS="['*']"  # Replace with actual hosts or use ['*'] for development
MEMCACHED_LOCATION="controller:11211"
TIME_ZONE="Asia/Ho_Chi_Minh" 

# Function to install OpenStack Dashboard
install_dashboard() {
    echo "Installing OpenStack Dashboard (Horizon)..."
    sudo apt install -y openstack-dashboard
    echo "OpenStack Dashboard installed."
}

# Function to configure OpenStack Dashboard settings in local_settings.py
configure_dashboard_settings() {
    local local_settings="/etc/openstack-dashboard/local_settings.py"

    # Backup the original local_settings.py file
    echo "Backing up the original local_settings.py file..."
    sudo cp "$local_settings" "${local_settings}.bak"

    # Configure OpenStack host
    echo "Configuring OpenStack host..."
    sudo sed -i "s/^OPENSTACK_HOST = .*/OPENSTACK_HOST = \"$OPENSTACK_HOST\"/" "$local_settings"

    # Set ALLOWED_HOSTS
    echo "Configuring ALLOWED_HOSTS..."
    sudo sed -i "s/^ALLOWED_HOSTS = .*/ALLOWED_HOSTS = $ALLOWED_HOSTS/" "$local_settings"
    
    echo "Comment out COMPRESS_OFFLINE..."
    sudo sed -i "/^COMPRESS_OFFLINE =/s/^/#/" "$local_settings"


    Configure memcached session storage
    echo "Configuring session storage with memcached..."
    # sudo sed -i "s|^SESSION_ENGINE = .*|SESSION_ENGINE = 'django.contrib.sessions.backends.cache'|" "$local_settings"
    sudo sed -i "/^CACHES = {/,+5 d" "$local_settings"
    cat <<EOF | sudo tee -a "$local_settings" > /dev/null
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.PyMemcacheCache',
        'LOCATION': '$MEMCACHED_LOCATION',
    }
}
EOF

    # # Comment out any other session storage configuration
    # echo "Commenting out other session storage configurations..."
    # sudo sed -i "/^SESSION_ENGINE =/!b;/^CACHES =/!b;s/^/#/" "$local_settings"

    # Enable Identity API version 3
    echo "Enabling Identity API version 3..."
    sudo sed -i "s|^OPENSTACK_KEYSTONE_URL = .*|OPENSTACK_KEYSTONE_URL = \"http://%s:5000/identity/v3\" % OPENSTACK_HOST|" "$local_settings"

    # Enable support for domains
    echo "Enabling Keystone multi-domain support..."
    echo "OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" >> "$local_settings"
    # sudo sed -i "s|^OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = .*|OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True|" "$local_settings"

    # Configure API versions
    echo "Configuring API versions..."
    sudo sed -i "/^OPENSTACK_API_VERSIONS = {/,+3 d" "$local_settings"
    cat <<EOF | sudo tee -a "$local_settings" > /dev/null
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 3,
}
EOF

    # Set default domain and role
    echo "Setting default domain and role..."

    echo "OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = \"Default\"" >> "$local_settings"
    echo "OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"" >> "$local_settings"

    # sudo sed -i "s|^OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = .*|OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = \"Default\"|" "$local_settings"
    # sudo sed -i "s|^OPENSTACK_KEYSTONE_DEFAULT_ROLE = .*|OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"|" "$local_settings"

    # Disable support for layer-3 networking services if required
    echo "Disabling layer-3 networking services (if required)..."
    sudo sed -i "/^OPENSTACK_NEUTRON_NETWORK = {/,+6 d" "$local_settings"
    cat <<EOF | sudo tee -a "$local_settings" > /dev/null
OPENSTACK_NEUTRON_NETWORK = {
    'enable_router': False,
    'enable_quotas': False,
    'enable_ipv6': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_fip_topology_check': False,
}
EOF

    # Set the time zone
    echo "Configuring time zone..."
    sudo sed -i "s|^TIME_ZONE = .*|TIME_ZONE = \"$TIME_ZONE\"|" "$local_settings"

    echo "Dashboard configuration in local_settings.py completed."
}

# Function to configure Apache for OpenStack Dashboard
configure_apache() {
    local apache_conf="/etc/apache2/conf-available/openstack-dashboard.conf"

    echo "Updating Apache configuration..."
    if ! grep -q "WSGIApplicationGroup %{GLOBAL}" "$apache_conf"; then
        echo "Adding WSGIApplicationGroup %{GLOBAL} to Apache configuration..."
        echo "WSGIApplicationGroup %{GLOBAL}" | sudo tee -a "$apache_conf" > /dev/null
    fi

    # Reload Apache to apply changes
    echo "Reloading Apache service..."
    sudo systemctl reload apache2.service
    echo "Apache configuration updated and reloaded."
}

# Function to run all setup steps
setup_openstack_dashboard() {
    install_dashboard
    configure_dashboard_settings
    configure_apache
    echo "OpenStack Dashboard (Horizon) setup completed."
}

# Execute the setup function
setup_openstack_dashboard
