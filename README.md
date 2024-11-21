# OpenStack Automation Script

This repository contains a set of scripts to automate the installation and configuration of OpenStack on a multi-node setup with one Controller node, one Compute node, and one Storage node. These scripts are intended for educational and experimental purposes, particularly in a cybersecurity lab environment.

Working with OpenStack 2024.1 and Ubuntu 22.04 LTS

![](./assets/demo.gif)

## Requirements

- **Operating System**: Ubuntu server 22.04
- **Virtualization Software**: VMware Workstation (or another compatible hypervisor)
- **Network Configuration**: Ensure the network topology matches the OpenStack requirements.

## Network Topology

![](./assets/network-topo.png)

Read more [here](https://docs.openstack.org/install-guide/environment-networking.html).


<table border="1">
    <thead>
        <tr>
            <th>Hostname</th>
            <th>NICs</th>
            <th>IP Address</th>
            <th>Gateway</th>
            <th>DNS</th>
            <th>RAM (GB)</th>
            <th>CPU</th>
            <th>DISK1 (GB)</th>
            <th>DISK2 (GB)</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan="2">controller</td>
            <td>ens33</td>
            <td>192.168.133.11/24</td>
            <td>192.168.133.2</td>
            <td>8.8.8.8</td>
            <td rowspan="2">8</td>
            <td rowspan="2">2</td>
            <td rowspan="2">40</td>
            <td rowspan="2"></td>
        </tr>
        <tr>
            <td>ens34</td>
            <td>10.0.0.11/24</td>
            <td></td>
            <td></td>
        </tr>
        <tr>
            <td rowspan="2">compute</td>
            <td>ens33</td>
            <td>192.168.133.21/24</td>
            <td>192.168.133.2</td>
            <td>8.8.8.8</td>
            <td rowspan="2">8</td>
            <td rowspan="2">4</td>
            <td rowspan="2">40</td>
            <td rowspan="2"></td>
        </tr>
        <tr>
            <td>ens34</td>
            <td>10.0.0.21/24</td>
            <td></td>
            <td></td>
        </tr>
        <tr>
            <td rowspan="2">block</td>
            <td>ens33</td>
            <td>192.168.133.31/24</td>
            <td>192.168.133.2</td>
            <td>8.8.8.8</td>
            <td rowspan="2">4</td>
            <td rowspan="2">2</td>
            <td rowspan="2">40</td>
            <td rowspan="2">100</td>
        </tr>
        <tr>
            <td>ens34</td>
            <td>10.0.0.31/24</td>
            <td></td>
            <td></td>
        </tr>
    </tbody>
</table>

## Installation

### 1. **Clone the Repository**

```bash
git clone https://github.com/phannhat17/openstack-script.git
cd openstack-script
find . -type f -exec chmod +x {} \;
cd scripts
```

### 2. **Prepare the Environment**

Ensure each node (Controller, Compute, Storage) is up and accessible as **root** within your network. Also, ensure that IPs are set correctly in the configuration files.

The Storage Node needs to have atleast two disks connected. And if this Node use LVM on the OS disk, read more [here](https://docs.openstack.org/cinder/2024.1/install/cinder-storage-install-ubuntu.html)

### 3. **Edit the Configuration Files**

`config.cfg`: This file contains configuration variables such as IP addresses, hostnames, network interfaces, and service passwords. Ensure that these values are set correctly before running the scripts.

### 4. **Run the IP config Script**

On each node (Controller, Compute, Storage), run the IP config script:

**Note: Run this inside the `scripts` folder**

```bash
./config_ip.sh
```

The script will prompt you to select which node (Controller, Compute, or Storage) you are configuring. It will then update the network settings adn reboot that node.

### 5. **Run the Service install Script**

On each node (Controller, Compute, Storage), run the service install script:

**Note: Run this inside the `scripts` folder**

```bash
./install_service.sh
```

The script will prompt you to select which node (Controller, Compute, or Storage) you are configuring.

## Service Endpoints

|   | Service             | Endpoint                 |
|---|---------------------|--------------------------|
| 1 | Openstack Dashboard | http://10.0.0.11/horizon |
| 2 | Prometheus          | http://10.0.0.10:9090    |
| 3 | Openstack exporter  | http://10.0.0.10:9180    |
| 4 | Grafana             | http://10.0.0.10:3000    |

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.