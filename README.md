# OpenStack Automation Script

This repository contains a set of scripts to automate the installation and configuration of OpenStack on a multi-node setup with one Controller node, one Compute node, and one Storage node. These scripts are intended for educational and experimental purposes, particularly in a cybersecurity lab environment.

## Requirements

- **Operating System**: Ubuntu server 22.04 or compatible Linux distribution
- **Virtualization Software**: VMware Workstation (or another compatible hypervisor)


## Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/phannhat17/openstack-script.git
   cd openstack-script
   find . -type f -exec chmod +x {} \;
   ```

2. **Prepare the Environment**

   Ensure each node (Controller, Compute, Storage) is up and accessible within your host-only network. Also, ensure that IPs are set correctly in the configuration files.

3. **Run the Script**

   - On each node (Controller, Compute, Storage), run the respective script:
   
     ```bash
     ./install-controller.sh  # Run this on the Controller Node
     ./install-compute.sh     # Run this on the Compute Node
     ./install-storage.sh     # Run this on the Storage Node
     ```

   Each script will install and configure the necessary OpenStack services for its respective node.


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Feel free to customize this README further as you add or update features in your project!