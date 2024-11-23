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

    # Generate Prometheus configuration file
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

  - job_name: 'openstack_node'
    static_configs:
      - targets: ["${CTL_MANAGEMENT}:9100", "${COM_MANAGEMENT}:9100", "${BLK_MANAGEMENT}:9100"]

  - job_name: 'vm_monitor'
    file_sd_configs:
      - files:
          - '/etc/prometheus/vm_monitor_targets.json'
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

# Function to generate dynamic Prometheus target file
generate_target_file() {
    echo -e "${YELLOW}Generating Prometheus target file...${RESET}"

    TARGET_FILE="/etc/prometheus/vm_monitor_targets.json"

    # Extract the subnet prefix from OS_PROVIDER_SUBNET
    SUBNET_PREFIX=$(echo "$OS_PROVIDER_SUBNET" | awk -F'.' '{print $1"."$2"."$3"."}')
    if [ -z "$SUBNET_PREFIX" ]; then
        echo -e "${RED}Failed to parse OS_PROVIDER_SUBNET. Ensure it's in CIDR format (e.g., 192.168.133.0/24).${RESET}"
        exit 1
    fi

    # Fetch server details from OpenStack
    source /root/admin-openrc
    SERVER_LIST=$(openstack server list -f json)

    # Parse targets for all VMs within the specified subnet
    VM_TARGETS=$(echo "$SERVER_LIST" | jq -r --arg prefix "$SUBNET_PREFIX" '.[] | .Networks | to_entries[] | .value[] | select(startswith($prefix))' | sed "s/$/:9100/")

    # Generate JSON content
    sudo tee "$TARGET_FILE" > /dev/null <<EOF
[
  {
    "targets": [
$(echo "$VM_TARGETS" | sed 's/^/      "/; s/$/",/' | sed '$ s/,$//')
    ],
    "labels": {
      "job": "vm_monitor"
    }
  }
]
EOF

    echo -e "${GREEN}Targets written to $TARGET_FILE.${RESET}"
}


# Function to set up a cron job for target file generation
setup_cron_job() {
    echo -e "${YELLOW}Setting up cron job for dynamic target updates...${RESET}"

    SCRIPT_PATH="/usr/local/bin/update_prometheus_targets.sh"

    # Create the script for updating targets
    sudo tee $SCRIPT_PATH > /dev/null <<EOF
#!/bin/bash
$(declare -f generate_target_file)
generate_target_file
EOF

    # Make the script executable
    sudo chmod +x $SCRIPT_PATH

    # Add cron job
    CRON_JOB="* * * * * $SCRIPT_PATH"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    echo -e "${GREEN}Cron job added to update targets every minute.${RESET}"
}

# Run the functions in sequence
install_prometheus
configure_prometheus
setup_systemd_service
generate_target_file
setup_cron_job

echo -e "${GREEN}Prometheus installed, configured, and dynamic target updates scheduled successfully.${RESET}"
