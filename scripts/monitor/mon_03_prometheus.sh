#!/bin/bash

# Load configuration from config.cfg
source config.cfg

# Function to install Prometheus
install_prometheus() {
    echo -e "${YELLOW}Installing Prometheus...${RESET}"

    # Extract Prometheus version from URL
    PROM_VERSION=$(echo "$PROMETHEUS_URL" | grep -oP 'v\K[0-9.]+')

    if [ -z "$PROM_VERSION" ]; then
        echo -e "${RED}Failed to extract Prometheus version from URL. Please check the URL.${RESET}"
        exit 1
    fi

    echo -e "${YELLOW}Detected Prometheus version: ${PROM_VERSION}${RESET}"

    # Download Prometheus tarball
    wget $PROMETHEUS_URL -O prometheus.tar.gz

    # Extract Prometheus files
    tar -xzf prometheus.tar.gz
    sudo mv prometheus-${PROM_VERSION}.linux-amd64 /usr/local/prometheus

    # Create Prometheus directories
    sudo mkdir -p /etc/prometheus /var/lib/prometheus
    sudo mv /usr/local/prometheus/prometheus.yml /etc/prometheus/

    # Cleanup downloaded tarball
    rm prometheus.tar.gz

    echo -e "${GREEN}Prometheus installed successfully.${RESET}"
}

# Function to configure Prometheus
configure_prometheus() {
    echo -e "${YELLOW}Configuring Prometheus...${RESET}"

    # Example configuration
    sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'openstack-exporter'
    static_configs:
      - targets: ['localhost:9180']
EOF

    echo -e "${GREEN}Prometheus configuration file created at /etc/prometheus/prometheus.yml.${RESET}"
}

# Function to set up Prometheus as a systemd service
setup_systemd_service() {
    echo -e "${YELLOW}Setting up Prometheus as a systemd service...${RESET}"

    # Create a systemd service file
    sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/prometheus/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable and start Prometheus service
    sudo systemctl daemon-reload
    sudo systemctl enable prometheus
    sudo systemctl start prometheus

    # Verify service status
    if systemctl is-active --quiet prometheus; then
        echo -e "${GREEN}Prometheus service is running.${RESET}"
    else
        echo -e "${RED}Failed to start Prometheus service.${RESET}"
        exit 1
    fi
}

# Run the functions in sequence
install_prometheus
configure_prometheus
setup_systemd_service

echo -e "${GREEN}Prometheus installed and configured successfully.${RESET}"
