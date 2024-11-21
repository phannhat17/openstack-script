#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to install Node Exporter
install_node_exporter() {
    echo -e "${YELLOW}Installing Node Exporter...${RESET}"

    # Extract version from URL
    NODE_EXPORTER_VERSION=$(echo "$NODE_EXPORTER_URL" | grep -oP 'v\K[0-9.]+')

    if [ -z "$NODE_EXPORTER_VERSION" ]; then
        echo -e "${RED}Failed to extract version from URL. Please check the URL.${RESET}"
        exit 1
    fi

    echo -e "${YELLOW}Detected version: ${NODE_EXPORTER_VERSION}${RESET}"


    # Download and extract Node Exporter
    wget $NODE_EXPORTER_URL -O node_exporter.tar.gz
    tar -xzf node_exporter.tar.gz
    sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64 /usr/local/node_exporter

    # Create symbolic link for easy access
    sudo ln -s /usr/local/node_exporter/node_exporter /usr/local/bin/node_exporter

    # Cleanup downloaded tarball
    rm node_exporter.tar.gz

    echo -e "${GREEN}Node Exporter installed successfully.${RESET}"
}

# Function to set up Node Exporter as a systemd service
setup_systemd_service() {
    echo -e "${YELLOW}Setting up Node Exporter as a systemd service...${RESET}"

    # Create a systemd service file
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable and start Node Exporter service
    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter

    # Verify service status
    if systemctl is-active --quiet node_exporter; then
        echo -e "${GREEN}Node Exporter service is running.${RESET}"
        echo -e "${GREEN}Node Exporter is accessible at http://<your-server-ip>:9100/metrics.${RESET}"
    else
        echo -e "${RED}Failed to start Node Exporter service.${RESET}"
        exit 1
    fi
}

# Run the functions in sequence
install_node_exporter
setup_systemd_service

echo -e "${GREEN}Node Exporter installed and configured successfully.${RESET}"
