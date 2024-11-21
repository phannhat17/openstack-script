#!/bin/bash

# Function to install prerequisites
install_prerequisites() {
    echo -e "${YELLOW}Installing prerequisite packages...${RESET}"
    sudo apt-get install -y apt-transport-https software-properties-common wget gpg
    echo -e "${GREEN}Prerequisite packages installed successfully.${RESET}"
}

# Function to add GPG key for Grafana
add_gpg_key() {
    echo -e "${YELLOW}Adding Grafana GPG key...${RESET}"
    sudo mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo -e "${GREEN}Grafana GPG key added successfully.${RESET}"
}

# Function to add Grafana repository
add_grafana_repository() {
    echo -e "${YELLOW}Adding Grafana repository...${RESET}"
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
    echo -e "${GREEN}Grafana repository added successfully.${RESET}"
}

# Function to update package list
update_package_list() {
    echo -e "${YELLOW}Updating package list...${RESET}"
    sudo apt-get update
    echo -e "${GREEN}Package list updated successfully.${RESET}"
}

# Function to install Grafana
install_grafana() {
    echo -e "${YELLOW}Installing Grafana...${RESET}"
    sudo apt-get install -y grafana
    echo -e "${GREEN}Grafana installed successfully.${RESET}"
}

# Function to start and enable Grafana service
setup_grafana_service() {
    echo -e "${YELLOW}Starting and enabling Grafana service...${RESET}"
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server
    echo -e "${GREEN}Grafana service is running.${RESET}"
    echo -e "${GREEN}Access Grafana at http://<your-server-ip>:3000 (default username: admin, password: admin).${RESET}"
}

# Run the functions in sequence
install_prerequisites
add_gpg_key
add_grafana_repository
update_package_list
install_grafana
setup_grafana_service

echo -e "${GREEN}Grafana installation and setup completed successfully.${RESET}"
