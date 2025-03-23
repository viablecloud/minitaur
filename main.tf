//Architecture as Code: The entire Cloud Environment Architecture is defined in this file "as code", meaning the components of the 
//architecture as well as the relationships between them are defined here in Terraform HCL.
//This represents the unified approach of "Architecture as Code" where infrastructure, automation, architecture and "state" are all aligned.

//1. Deploy the central (hub) VNET with a standard subnet layout, including one subnet for each of: "dev", "uat" and "prod" (environments are separated at network level, with NSGs)
data "azurerm_subscription" "current" {}

module "spoke_virtual_network" {

  source = "./modules/terraform-azurerm-vnet"

  # By default, this module will not create a resource group, proivde the name here
  # to use an existing resource group, specify the existing resource group name,
  # and set the argument to `create_resource_group = true`. Location will be same as existing RG.

  create_resource_group = true //unless you know better ...
  resource_group_name   = "network-rsg"

  vnetwork_name                  = "vnet-hub"
  location                       = var.primary_location
  vnet_address_space             = ["10.216.32.0/20"] //e.g 10.218.16.0/20
  firewall_subnet_address_prefix = ["10.216.33.0/24"] //e.g 10.218.16.0/24
  gateway_subnet_address_prefix  = ["10.216.32.0/24"] //10.218.17.0/24
  create_network_watcher         = false

  //You'll need this is you're doing hybrid or multi-cloud networking with multiple VNETs communicating over a WAN.
  bgp_community = "12076:20211" //e.g "12076:20200"

  # Adding Standard DDoS Plan, and custom DNS servers (Optional)
  # WARNING:: EXPENSIVE!
  create_ddos_plan = false //this should only be needed in the hub net anyway ...

  # Multiple Subnets, Service delegation, Service Endpoints, Network security groups
  # These are default subnets with required configuration, check README.md for more details
  # NSG association to be added automatically for all subnets listed here.
  # First two address ranges from VNet Address space reserved for Gateway And Firewall Subnets.
  # ex.: For 10.1.0.0/16 address space, usable address range start from 10.1.2.0/24 for all subnets.
  # subnet name will be set as per Azure naming convention by defaut. expected value here is: <App or project name>
  subnets = {
    mgnt_subnet = {
      subnet_name           = "mgnt-sbnt"
      subnet_address_prefix = ["10.216.34.0/24"] //e.g 10.218.18.0/24


      //Example Delegation for containerGroups
      //Enable this delegation for ACS
      delegation = {
        name = "containerdelegation"
        service_delegation = {
          name    = "Microsoft.ContainerInstance/containerGroups"
          actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
        }
      }

      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["web-insecure-0006", "110", "Inbound", "Allow", "Tcp", "80", "*", "0.0.0.0/0"],
        ["web-secure-0006", "100", "Inbound", "Allow", "Tcp", "443", "*", "0.0.0.0/0"],

      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["ntp-out-0007", "110", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
        ["web-insecure-0007", "130", "Outbound", "Allow", "Tcp", "80", "", "0.0.0.0/0"],
        ["web-secure-0007", "120", "Outbound", "Allow", "Tcp", "443", "", "0.0.0.0/0"],
        ["dns-udp-0007", "140", "Outbound", "Allow", "Udp", "53", "", "0.0.0.0/0"],
        ["dns-tcp-0007", "150", "Outbound", "Allow", "Tcp", "53", "", "0.0.0.0/0"],

      ]
    }

    dmz_subnet = {
      subnet_name           = "dns-sbnt"
      subnet_address_prefix = ["10.216.35.0/24"] //e.g 10.218.19.0/24
      service_endpoints     = ["Microsoft.Storage"]

      delegation = {
        name = "serverFarmsdelegation"
        service_delegation = {
          name    = "Microsoft.Web/serverFarms"
          actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
      }

      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["web-insecure-0000", "200", "Inbound", "Allow", "Tcp", "80", "*", ""],
        ["web-secure-0000", "210", "Inbound", "Allow", "Tcp", "443", "AzureLoadBalancer", ""],
      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["ntp-out-0001", "103", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0", ""],
        ["web-insecure-0001", "130", "Outbound", "Allow", "Tcp", "80", "", "0.0.0.0/0"],
        ["web-secure-0001", "120", "Outbound", "Allow", "Tcp", "443", "", "0.0.0.0/0"],
        ["dns-udp-0001", "140", "Outbound", "Allow", "Udp", "53", "", "0.0.0.0/0"],
        ["dns-tcp-0001", "150", "Outbound", "Allow", "Tcp", "53", "", "0.0.0.0/0"],

      ]
    }

    lz000_subnet000 = {
      subnet_name           = "sbnt-000"
      subnet_address_prefix = ["10.216.36.0/24"] //e.g "10.218.20.0/24"
      service_endpoints     = ["Microsoft.Storage", "Microsoft.KeyVault"]

      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["web-secure-0002", "100", "Inbound", "Allow", "Tcp", "443", "*", "0.0.0.0/0"],
      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["ntp-out-0003", "110", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
        ["web-insecure-0003", "120", "Outbound", "Allow", "Tcp", "80", "", "0.0.0.0/0"],
        ["web-secure-0003", "130", "Outbound", "Allow", "Tcp", "443", "", "0.0.0.0/0"],
        ["dns-udp-0003", "140", "Outbound", "Allow", "Udp", "53", "", "0.0.0.0/0"],
        ["dns-tcp-0003", "150", "Outbound", "Allow", "Tcp", "53", "", "0.0.0.0/0"],
      ]
    }

    lz000_subnet001 = {
      subnet_name           = "subnet-001"
      subnet_address_prefix = ["10.216.37.0/24"] //e.g 10.218.21.0/24
      service_endpoints     = ["Microsoft.Storage"]

      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["weballow-0004", "200", "Inbound", "Allow", "Tcp", "443", "*", "0.0.0.0/0"],
        ["web-insecure-0004", "210", "Outbound", "Allow", "Tcp", "80", "", "0.0.0.0/0"],
        ["web-secure-0004", "220", "Outbound", "Allow", "Tcp", "443", "", "0.0.0.0/0"],
        ["dns-udp-0004", "230", "Outbound", "Allow", "Udp", "53", "", "0.0.0.0/0"],
        ["dns-tcp-0004", "240", "Outbound", "Allow", "Tcp", "53", "", "0.0.0.0/0"],

      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["ntp-out-0005", "150", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
        ["web-insecure-0005", "160", "Outbound", "Allow", "Tcp", "80", "", "0.0.0.0/0"],
        ["web-secure-0005", "1170", "Outbound", "Allow", "Tcp", "443", "", "0.0.0.0/0"],
        ["dns-udp-0005", "180", "Outbound", "Allow", "Udp", "53", "", "0.0.0.0/0"],
        ["dns-tcp-0005", "190", "Outbound", "Allow", "Tcp", "53", "", "0.0.0.0/0"],
      ]
    }

    //AzureBastionSubnetBastion Subnet
    AzureBastionSubnet = {
      subnet_name           = "AzureBastionSubnet"
      subnet_address_prefix = ["10.216.38.0/24"] //e.g 10.218.21.0/28
      service_endpoints     = []

    }

    //subnet 003
    lz000_subnet003 = {
      subnet_name           = "subnet-003"
      subnet_address_prefix = ["10.216.39.0/24"] //e.g 10.218.21.0/28
      service_endpoints     = ["Microsoft.Storage"]

    }

    //subnet 004
    lz000_subnet004 = {
      subnet_name           = "subnet-004"
      subnet_address_prefix = ["10.216.40.0/24"] //e.g 10.218.21.0/28
      service_endpoints     = ["Microsoft.Storage"]
    }

    //Next: subnet 005
    /*
    lz000_subnet005 = {
      subnet_name           = "subnet-005"
      subnet_address_prefix = ["10.216.41.0/24"] //e.g 10.218.21.0/28
      service_endpoints     = []
    }
    */

    //Continue adding subnets as needed ...

  }

  # Adding TAG's to your Azure resources (Required)
  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }

}

//2. Deploy a single VM for hosting initial docker container services (e.g management tools, bootstrap ci/cd, auto-documentation, website hosting)
//3. Deploy an application gateway to expose applications to the internet with an initial "read-only" service exposed to the internet.
//4. Deploy ACR for container image storage.
//5. Deploy an common file sharing service for private storage in the environment
//6. Deploy an Azure Keyvault for Secrets storage and retrieval automation
//7. Deploy a spoke vnet dedicated to Kubernetes workloads, peered to the hub vnet, with access to the internet via the Application gateway.

//Secondary VNET dedicated to hosting AKS workloads. 
//Due to the high IP address consumption of AKS, we need to deploy a separate VNET for the AKS cluster.
//This VNET is peered to the hub VNET, and to the primary VNET.
//The AKS cluster is deployed in the secondary VNET, and the subnet is dedicated to AKS workloads.

module "vnet_secondary" {

  source = "./modules/terraform-azurerm-vnet"

  vnetwork_name          = "secondary-vnet"
  create_resource_group  = true //unless you know better ...
  location               = var.primary_location
  vnet_address_space     = ["10.216.48.0/20"]
  bgp_community          = "12076:20212"
  create_network_watcher = false

  subnets = {
    gateway = {
      subnet_name           = "gateway"
      subnet_address_prefix = ["10.216.48.0/24"]
      service_endpoints     = ["Microsoft.Storage"]

    }
    mgmt = {
      subnet_name           = "mgmt"
      subnet_address_prefix = ["10.216.49.0/24"]
    }
    dmz = {
      subnet_name           = "dmz"
      subnet_address_prefix = ["10.216.50.0/24"]
    }


    aks-subnet = {
      subnet_name           = "aks-subnet"
      subnet_address_prefix = ["10.216.52.0/22"] // Changed from 51 to 52 to avoid overlap
      service_endpoints     = ["Microsoft.Storage", "Microsoft.KeyVault"]
    }

  }

  tags = {
    environment = "production"
    purpose     = "spoke-network"
  }
}

//Bi-directional peering between the hub and the secondary vnet

// Peering link between the hub and the secondary vnet
resource "azurerm_virtual_network_peering" "hub_to_secondary" {
  name                         = "peering-hub-to-secondary"
  resource_group_name          = module.spoke_virtual_network.resource_group_name // From the hub VNET module
  virtual_network_name         = module.spoke_virtual_network.virtual_network_name
  remote_virtual_network_id    = module.vnet_secondary.virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

// Peering link from secondary to hub (required for bi-directional peering)
resource "azurerm_virtual_network_peering" "secondary_to_hub" {
  name                         = "peering-secondary-to-hub"
  resource_group_name          = module.vnet_secondary.resource_group_name // From the hub VNET module
  virtual_network_name         = module.vnet_secondary.virtual_network_name
  remote_virtual_network_id    = module.spoke_virtual_network.virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

//Deploy a Generic Linux DMZ server in the DMZ subnet of the hub VNET
module "linux_vm_dmz" {
  source              = "./modules/compute-linux"
  resource_group_name = module.spoke_virtual_network.resource_group_name
  location            = var.primary_location
  vnet_subnet_id      = module.spoke_virtual_network.subnet_ids[2] //Third subnet in the VNET
  server_name         = "hub-dmz-linux-vm"
  admin_username      = "azureuser"
  admin_password      = "P@ssw0rd1234!"

}

//Deploy a Generic Linux DMZ server in the DMZ subnet of the secondary VNET
module "linux_vm_dmz_secondary" {
  source              = "./modules/compute-linux"
  resource_group_name = module.vnet_secondary.resource_group_name
  location            = var.primary_location
  vnet_subnet_id      = module.vnet_secondary.subnet_ids[2] //Third subnet in the VNET
  server_name         = "spoke-dmz-linux-vm"
  admin_username      = "azureuser"
  admin_password      = "P@ssw0rd1234!"

}

//Deploy a Secure Bastion service for the hub VNET
//assign a public address to the bastion
resource "azurerm_public_ip" "hub_vnet_bastion_pip" {
  name                = "hub-vnet-bastion-pip"
  location            = var.primary_location
  resource_group_name = module.spoke_virtual_network.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  # Adding TAG's to your Azure resources (Required)
  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }

}

//Deploy Bastion Service for the hub VNET to allow secure RDP/SSH access to the VMs in the VNET
//by default commented out because Bastion Service is expensive
//NOTE: Ensure "AzureBastionSubnet" is added as a subnet in the VNET BEFORE YOU RUN THIS PART OF THE CODE, 
//and that it has a public IP address assigned to it.

resource "azurerm_bastion_host" "hub_vnet_bastion" {
  name                = "hub-vnet-bastion"
  location            = var.primary_location
  resource_group_name = module.spoke_virtual_network.resource_group_name

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = module.spoke_virtual_network.subnet_ids_map["AzureBastionSubnet"]
    public_ip_address_id = azurerm_public_ip.hub_vnet_bastion_pip.id
  }

  # Adding TAG's to your Azure resources (Required)
  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }

}



//Deploy a utility VM as an alternative to kubernetes for running simple workloads and providing initial management tools for the environment.
/*
*******  THIS VIRTUAL MACHINE CONFIGURATION IS AN EXAMPLE OF A SIMPLE CONTAINERISATION SOLUTION WITHOUT KUBERNETES OR ACS ***********
*******  USE THIS AS A CHEAPER, SIMPLER ALTERNATIVE TO KUBERNETES WHEN YOU DON'T NEED THE FEATURES OF KUBERNETES ***********
*******  DEPLOYING THIS VM WILL RESULT IN A DOCKERISED VIRTUAL MACHINE WITH INSTALLATION CUSTOMISED ACCORDING TO THE PROVIDED SCRIPTS ***********
*******  To fully customise the "bootup" configuration of this vm, modify the "custom_data"section of this code to your needs ***********
*/

//get the Azure Container Instances Contributor Role
data "azurerm_role_definition" "aci_contributor" {
  name = "Azure Container Instances Contributor Role"
}

resource "azurerm_resource_group" "standalone_services_rsg" {
  name     = "standalone-services-rsg"
  location = var.primary_location

  tags = {

    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Team             = local.deploy_environment["team"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]

  }
}

//Alternative solution to ACS and AKS is a basic VM running docker with a deploy image
resource "azurerm_linux_virtual_machine" "vmagent_host" {
  name                            = "vmagent"
  resource_group_name             = azurerm_resource_group.standalone_services_rsg.name
  location                        = azurerm_resource_group.standalone_services_rsg.location
  size                            = "Standard_F2"
  disable_password_authentication = false //Remove this eventually
  admin_username                  = var.vmagent_local_username
  admin_password                  = var.vmagent_local_password

  //this allows the VM to performance orchestration on containers
  identity {
    type = "SystemAssigned"
  }

  network_interface_ids = [
    azurerm_network_interface.gitops_vmagent_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<CLOUD_INIT
#cloud-config
write_files:

  - path: /root/.docker/config.json
    content: |
        {
            "auths": {
                "quay.io": {
                    "auth": "dHdlbGNvbWU6Q3I0Y2tNMG5rM3khIQ=="
                }
            }
        }

  - path: /root/rebuild.sh
    content: |
     #!/bin/bash
      #System Management Server Installation Script
      #bootstrap script to install the default management components 
      #for customer landing zone management
      #(C) WHCO LTD. - 2024

      function upgrade () {
              printf "\n 1. Updating and patching this virtual machine\n"
              apt-get -y update
      }

      function containerise () {
              printf "\n 2. Installing docker services\n"
              preparate
              dockerize
      }

      function preparate () {
              printf "\n2. Preparing docker pre-requisites and avoiding dependency conflicts\n"
              for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
              do
                      apt-get remove $pkg
              done
              apt-get -y install git
      }

      function dockerize () {
              printf "\nInstalling docker services.\n"
              # Add Docker's official GPG key:
              sudo apt-get update
              sudo apt-get install ca-certificates curl
              sudo install -m 0755 -d /etc/apt/keyrings
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              sudo chmod a+r /etc/apt/keyrings/docker.asc
              # Add the repository to Apt sources:
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update
              #installing the latest version of docker
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      }

      function installDeployer () {
              printf "\n 3. Installing functional containers: Jenkins deployer\n"
              docker stop `docker ps | egrep "engeneon" | awk -s '{print $1}'`
              docker run -d -p 8080:8080 quay.io/twelcome/engeneon:0.1.8
              for i in `seq 1 5`
              do
                      printf "$i - $(docker ps)\n"
              done
      }

      function installWebhookProcessor () {
              printf "\n 3. Installing functional containers: Webhook processor\n"
              docker stop `docker ps | egrep "webhook" | awk -s '{print $1}'`
              docker run --pull=always -d -p 8888:8888 quay.io/twelcome/webhook:latest
              for i in `seq 1 5`
              do
                      printf "$i - $(docker ps)\n"
              done
      }

      function installTLSsink () {
              printf "\n 3. Installing functional containers: TLS Sink Service\n"
              docker stop `docker ps | egrep "tls-sink" | awk -s '{print $1}'`
              docker run -d -p 443:443 quay.io/twelcome/tls-sink:0.0.8
              for i in `seq 1 5`
              do
                      printf "$i - $(docker ps)\n"
              done
      }

      function report () {
              printf "\n 4. Reporting on installation result\n"
              sudo docker run hello-world
      }

      printf "\n ========= starting digital transformation ========\n"

      upgrade
      containerise
      installDeployer
      installWebhookProcessor
      installTLSsink
      report

      printf "\n ========= digital transformation complete ========\n"

  - path: /var/lib/cloud/instance/scripts/part-002
    content: |
      #!/bin/bash
      sudo su -
      (crontab -l 2>/dev/null; echo "@reboot bash /root/rebuild.sh") | crontab -
    permissions: "0755"
  - path: /var/lib/cloud/instance/scripts/part-001
    content: |
      #!/bin/bash
      bash /root/rebuild.sh
    permissions: "0755"
CLOUD_INIT
  )

  # Adding TAG's to your Azure resources (Required)
  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }

}

//NIC for deployer vm
//Deployer VM is used as a Cheaper alternative to ACS and Kubernetes
resource "azurerm_network_interface" "gitops_vmagent_nic" {
  name                = "vmagent-nic"
  resource_group_name = azurerm_resource_group.standalone_services_rsg.name
  location            = azurerm_resource_group.standalone_services_rsg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.vnet_secondary.subnet_ids_map["gateway"]
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.216.48.14" //picked manually based on static configuration. You can modify this using available addresses in the relevant subnet.
  }

  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }
}

//Give this virtual machine administrative powers ...
resource "azurerm_role_assignment" "container_administration" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = "${data.azurerm_subscription.current.id}${data.azurerm_role_definition.aci_contributor.id}"
  principal_id       = azurerm_linux_virtual_machine.vmagent_host.identity[0].principal_id
}

//variables
variable "vmagent_ssh_username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "adjudicator"
}

variable "vmagent_local_username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "adjudicator"
}

variable "vmagent_local_password" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "Cr4ck3rJ4ck##"
}

//Managed disks to expand the storage capacity of the VM
resource "azurerm_managed_disk" "vmagent_disk1" {
  name                 = "vm000-disk1"
  resource_group_name  = azurerm_resource_group.standalone_services_rsg.name
  location             = azurerm_resource_group.standalone_services_rsg.location
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 100

  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }
}

//Attach the disks to the VM
resource "azurerm_virtual_machine_data_disk_attachment" "vmagent_disk1_attachment" {
  managed_disk_id    = azurerm_managed_disk.vmagent_disk1.id
  virtual_machine_id = azurerm_linux_virtual_machine.vmagent_host.id
  lun                = "1"
  caching            = "ReadWrite"
}

  //The central application gateway for the environment.
  //This is used to manage inbound and outbound traffic to the environment from the internet.
  //Ideally this should be deployed in conjunction with a cloud firewall like Azure Firewall.
  //However, perhaps for your use case the WAF feature of Application Gateway is sufficient.

  //THE FOLLOWING IS A BLUEPRINT FOR THE APPLICATION GATEWAY. THE APPLICATION GATEWAY PROVIDES A SCALABLE SOLUTION
  //TO PROVIDING ACCESS TO SERVICES IN LANDING ZONE SPOKES BY THE CUSTOMERS USERS (APP SERVICE USERS).
  //IT SUPPORTS WAF FOR SECURITY AND CAN BE INTEGRATED WITH AZURE FIREWALL IN A LIMITED WAY FOR ADDITIONAL SECURITY

  resource "azurerm_resource_group" "app_gateway_rsg" {
    name     = "app-gateway-rsg"
    location = var.primary_location
    tags = {
      Environment      = local.deploy_environment["environment"]
      ApplicationOwner = local.deploy_environment["owner"]
      Application      = local.deploy_environment["application"]
      CostCenter       = local.deploy_environment["costcenter"]
      Department       = local.deploy_environment["department"]
    }
  }

  //Create a public IP address for the application gateway
  resource "azurerm_public_ip" "app_gateway_pip" {
    name                = "appgw-pip-0000"
    resource_group_name = azurerm_resource_group.app_gateway_rsg.name
    location            = var.primary_location
    allocation_method   = "Static"
    sku                 = "Standard"
  }

  //User assigned identity
  resource "azurerm_user_assigned_identity" "appgw_managed_id" {
    name                = "appgw-managed-id"
    resource_group_name = azurerm_resource_group.app_gateway_rsg.name
    location            = azurerm_resource_group.app_gateway_rsg.location
  }

  //THE FOLLOWING IS A BLUEPRINT FOR THE APPLICATION GATEWAY. THE APPLICATION GATEWAY PROVIDES A SCALABLE SOLUTION
  //TO PROVIDING ACCESS TO SERVICES IN LANDING ZONE SPOKES BY THE CUSTOMERS USERS (APP SERVICE USERS).
  //IT SUPPORTS WAF FOR SECURITY AND CAN BE INTEGRATED WITH AZURE FIREWALL IN A LIMITED WAY FOR ADDITIONAL SECURITY

  //Define a group of variables to simplify naming convention
  locals {

      app1_target_fqdns = [
          "manage.mini.int"
      ]

    app1_backend_address_pool_name      = "lz000app1-internet-beap"
    app1_frontend_port_name             = "lz000app1-internet-feport"
    app1_frontend_secure_port_name      = "lz000app1-internet-feport-secure"
    app1_frontend_ip_configuration_name = "lz000app1-internet-feip"
    app1_http_setting_name              = "lz000app1-internet-be-htst"
    app1_listener_name                  = "lz000app1-internet-httplstn" 
    app1_request_routing_rule_name      = "lz000app1-internet-rqrt"

  }

  //Finally we get to the part where we create the actual Application Gateway
  //NOTE: THIS APPLICATION GATEWAY IS MEANT TO BE POINTED DIRECTLY AT APPLICATIONS HOSTED ON A VM OR DIRECTLY AT 
  //A KUBERNETES POD IP ADDRESS. IF YOU ALREADY HAVE AN INGRESS WITH AN EXTERNAL IP ADDRESS USE THE INGRESS 
  //CONFIGURED IN `kubernetes.tf`, NOT THIS ONE!!
  resource "azurerm_application_gateway" "application_gateway" {
    name                = "app-gw"
    resource_group_name = azurerm_resource_group.app_gateway_rsg.name
    location            = azurerm_resource_group.app_gateway_rsg.location

    //required to obtain TLS certificate from Azure Keyvault
    identity {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.appgw_managed_id.id]
    }

    //Supported SKUs: Standard_Small Standard_Medium Standard_Large Standard_v2 WAF_Large WAF_Medium WAF_v2
    sku {
      name     = "Standard_v2"
      tier     = "Standard_v2"
      capacity = 2
    }

    gateway_ip_configuration {
      name      = "hub00-apgw"
      subnet_id = module.spoke_virtual_network.subnet_ids_map["subnet-003"]
    }

    frontend_port {
      name = local.app1_frontend_port_name
      port = 80
    }

    frontend_port {
      name = local.app1_frontend_secure_port_name
      port = 443
    }

    frontend_ip_configuration {
      name                 = local.app1_frontend_ip_configuration_name
      public_ip_address_id = azurerm_public_ip.app_gateway_pip.id
    }

    //------------------------------------ EXAMPLE #1 ---------------------------------------------
    //app-1
    backend_address_pool {
      name  = local.app1_backend_address_pool_name
      fqdns = local.app1_target_fqdns
    }

    backend_http_settings {
      name                  = local.app1_http_setting_name
      cookie_based_affinity = "Enabled"
      path                  = "/"
      port                  = 8080
      protocol              = "Http"
      request_timeout       = 15
    }

    http_listener {
      name                           = local.app1_listener_name
      frontend_ip_configuration_name = local.app1_frontend_ip_configuration_name
      frontend_port_name             = local.app1_frontend_port_name
      protocol                       = "Http"
      host_names                     = ["blog.viable.one"]
    }

    request_routing_rule {
      name                       = local.app1_request_routing_rule_name
      priority                   = 17
      rule_type                  = "Basic"
      http_listener_name         = local.app1_listener_name
      backend_address_pool_name  = local.app1_backend_address_pool_name
      backend_http_settings_name = local.app1_http_setting_name
    }
    //---------------------------------------------------------------------------------

  }

//------------------------------------ BEGIN: Secure Azure Keyvault to storage initial infrastructure automation and access secrets ---------------------------------------------
# Create Resource Group for Key Vault
resource "azurerm_resource_group" "kv_rg" {
  name     = "rg-kv-${var.location_short}-${var.deployment_environment}"
  location = var.primary_location
  
  tags = local.deploy_environment
}

# Create Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.kv_rg.name
  
  tags = local.deploy_environment
}

# Link Private DNS Zone to VNets
resource "azurerm_private_dns_zone_virtual_network_link" "kv_hub" {
  name                  = "kv-hub-link"
  resource_group_name   = azurerm_resource_group.kv_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = module.spoke_virtual_network.virtual_network_id
  
  tags = local.deploy_environment
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_secondary" {
  name                  = "kv-secondary-link"
  resource_group_name   = azurerm_resource_group.kv_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = module.vnet_secondary.virtual_network_id
  
  tags = local.deploy_environment
}

# Deploy Key Vault using the AVM module
module "key_vault" {
  source = "./modules/terraform-azurerm-avm-res-keyvault-vault"

  # Required Parameters
  name                = "kv-${var.organisation_id}-${var.deployment_environment}-${var.location_short}-001"
  resource_group_name = azurerm_resource_group.kv_rg.name
  location            = azurerm_resource_group.kv_rg.location
  tenant_id          = data.azurerm_client_config.current.tenant_id

  # Enable Private Endpoint
  private_endpoints = {
    primary = {
      private_dns_zone_resource_group_name = azurerm_resource_group.kv_rg.name
      private_dns_zone_name                = "privatelink.vaultcore.azure.net"
      subnet_resource_id                   = module.spoke_virtual_network.subnet_ids_map["sbnt-000"]
      subresource_names                    = ["vault"]
    }
    
    secondary = {
      private_dns_zone_resource_group_name = azurerm_resource_group.kv_rg.name
      private_dns_zone_name                = "privatelink.vaultcore.azure.net"
      subnet_resource_id                   = module.vnet_secondary.subnet_ids_map["aks-subnet"]
      subresource_names                    = ["vault"]
    }
  }

  # Network ACLs
  network_acls = {
    bypass                     = "AzureServices"
    default_action            = "Deny"
    ip_rules                  = [
      "118.200.181.33"
      ]
    virtual_network_subnet_ids = [
      module.spoke_virtual_network.subnet_ids_map["sbnt-000"],
      module.vnet_secondary.subnet_ids_map["aks-subnet"]
    ]
  }

  # Enable RBAC
  //enable_rbac_authorization = true
  
  # Access Policies for Managed Identities
  role_assignments = {
    # VM Access
    vm_secrets = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = azurerm_linux_virtual_machine.vmagent_host.identity[0].principal_id
    }
    
    # AKS Access
    aks_secrets = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = module.aks.kubelet_identity[0].object_id
    }
    
    # App Gateway Access
    appgw_secrets = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = azurerm_user_assigned_identity.appgw_managed_id.principal_id
    }
  }

  # Basic Key Vault Configuration
  sku_name                    = "premium"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 7

  tags = local.deploy_environment
}

# Output the Key Vault ID for reference
output "key_vault_id" {
  value = module.key_vault.resource_id
}

//------------------------------------ END: Azure Keyvault to storage initial infrastructure automation and access secrets ---------------------------------------------

//Output the public IP address of the application gateway
output "application_gateway_public_ip" {
  description = "The public IP address of the application gateway"
  value       = azurerm_public_ip.app_gateway_pip.ip_address
}
