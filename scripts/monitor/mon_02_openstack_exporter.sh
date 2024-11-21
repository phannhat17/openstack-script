#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to install OpenStack Exporter
install_openstack_exporter() {
    echo -e "${YELLOW}Installing OpenStack Exporter...${RESET}"

    # Download and extract the OpenStack Exporter
    wget $EXPORTER_URL -O openstack-exporter.tar.gz
    tar -xzf openstack-exporter.tar.gz
    sudo mv openstack-exporter /usr/local/bin/
    rm openstack-exporter.tar.gz

    # Confirm installation
    if [ -f /usr/local/bin/openstack-exporter ]; then
        echo -e "${GREEN}OpenStack Exporter installed successfully.${RESET}"
    else
        echo -e "${RED}OpenStack Exporter installation failed.${RESET}"
        exit 1
    fi
}

# Function to create configuration YAML
create_config_yaml() {
    echo -e "${YELLOW}Creating configuration YAML for OpenStack Exporter...${RESET}"

    # Create the configuration directory
    sudo mkdir -p /etc/openstack-exporter/

    # Create the configuration YAML file
    sudo tee /etc/openstack-exporter/config.yaml > /dev/null <<EOF
clouds:
  my-cloud:
    region_name: RegionOne
    auth:
      auth_url: http://controller:5000/v3
      username: admin
      password: $ADMIN_PASS
      project_name: admin
      user_domain_name: Default
      project_domain_name: Default
    verify: false
EOF

    echo -e "${GREEN}Configuration YAML created at /etc/openstack-exporter/config.yaml.${RESET}"
}

# Function to set up OpenStack Exporter as a systemd service
setup_systemd_service() {
    echo -e "${YELLOW}Setting up OpenStack Exporter as a systemd service...${RESET}"

    # Create a systemd service file
    sudo tee /etc/systemd/system/openstack-exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus OpenStack Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/openstack-exporter --os-client-config /etc/openstack-exporter/config.yaml my-cloud
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable openstack-exporter
    sudo systemctl start openstack-exporter

    # Verify the service status
    if systemctl is-active --quiet openstack-exporter; then
        echo -e "${GREEN}OpenStack Exporter service is running.${RESET}"
    else
        echo -e "${RED}Failed to start OpenStack Exporter service.${RESET}"
        exit 1
    fi
}

# Run the functions in sequence
install_openstack_exporter
create_config_yaml
setup_systemd_service

echo -e "${GREEN}OpenStack Exporter installed and configured successfully.${RESET}"
