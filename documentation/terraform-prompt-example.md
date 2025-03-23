The folder contains terraform code and modules (under ./modules/) which currently configured to deploy an Azure VNET.
The VNET configuration is contained in main.tf.

Use the terraform modules in ./module/terraform-azurerm-vnet and the example in main.tf to create a second VNET in the same subscription and a different resource group with the  following configuration:

1. VNET IP address range = 10.216.48.0/20
2. BGP Community String=12076:20212
3. gateway_subnet_address_prefix=10.216.48.0/24
4. mgmt_subnet_address_prefix=10.216.49.0/24
5. dmz_subnet_address_prefix=10.216.50.0/24
6. Use the rest of the available address space in the VNET to create a single subnet.

Do not associate a Network Security Group (NSG) on any subnet in the new VNET.

---

Update the code with these specifications:

- name the vnet resource group "vnet-spoke-000-rsg"
- set the VNET location to eastasia
- Rename the "general" subnet to "aks-subnet"
- generate code for the prerequisite resource group


--- 10.216.51.0/21 ----


Given that a VNET is assigned the address space: 10.216.48.0/20, the following three subnets are defined:

10.216.48.0/24
10.216.49.0/24
10.216.50.0/24

What is the maximum size subnet that may be created with the remaining address space?

---

When running terraform plan I receive the following errors:

```
╷
│ Error: creating Subnet: (Name "aks-subnet" / Virtual Network Name "secondary-vnet" / Resource Group "rg-demo-westeurope-01"): 
network.SubnetsClient#CreateOrUpdate: Failure sending request: StatusCode=400 -- Original Error: Code="InvalidCIDRNotation" Message="The address prefix 10.216.52.0/21 in 
resource /subscriptions/4decbd3a-55d4-453f-a7ad-17327cff8f01/resourceGroups/rg-demo-westeurope-01/providers/Microsoft.Network/virtualNetworks/secondary-vnet/subnets/aks-subnet has an invalid CIDR notation. 
For the given prefix length, the address prefix should be 10.216.48.0/21." Details=[]
│ 
│   with module.vnet_secondary.azurerm_subnet.snet["aks-subnet"],
│   on modules/terraform-azurerm-vnet/main.tf line 99, in resource "azurerm_subnet" "snet":
│   99: resource "azurerm_subnet" "snet" {
│ 
```




```
    ╷
│ Error: creating Subnet: (Name "aks-subnet" / Virtual Network Name "secondary-vnet" / Resource Group "rg-demo-westeurope-01"): network.SubnetsClient#CreateOrUpdate: Failure sending request: StatusCode=400 -- Original Error: Code="NetcfgSubnetRangesOverlap" Message="Subnet 'aks-subnet' is not valid because its IP address range overlaps with that of an existing subnet in virtual network 'secondary-vnet'." Details=[]
│ 
│   with module.vnet_secondary.azurerm_subnet.snet["aks-subnet"],
│   on modules/terraform-azurerm-vnet/main.tf line 99, in resource "azurerm_subnet" "snet":
│   99: resource "azurerm_subnet" "snet" {
│ 
╵
```


    ```╷
    │ Error: Unsupported attribute
    │ 
    │   on modules/terraform-azurerm-vnet/main.tf line 101, in resource "azurerm_subnet" "snet":
    │  101:   name                                           = each.value.subnet_name
    │     ├────────────────
    │     │ each.value is object with 2 attributes
    │ 
    │ This object does not have an attribute named "subnet_name".
    ╵
    ╷
    │ Error: Unsupported attribute
    │ 
    │   on modules/terraform-azurerm-vnet/main.tf line 101, in resource "azurerm_subnet" "snet":
    │  101:   name                                           = each.value.subnet_name
    │     ├────────────────
    │     │ each.value is object with 2 attributes
    │ 
    │ This object does not have an attribute named "subnet_name".
    ╵
    ╷
    │ Error: Unsupported attribute
    │ 
    │   on modules/terraform-azurerm-vnet/main.tf line 101, in resource "azurerm_subnet" "snet":
    │  101:   name                                           = each.value.subnet_name
    │     ├────────────────
    │     │ each.value is object with 2 attributes
    │ 
    │ This object does not have an attribute named "subnet_name".
    ╵
    ╷
    │ Error: Unsupported attribute
    │ 
    │   on modules/terraform-azurerm-vnet/main.tf line 101, in resource "azurerm_subnet" "snet":
    │  101:   name                                           = each.value.subnet_name
    │     ├────────────────
    │     │ each.value is object with 2 attributes
    │ 
    │ This object does not have an attribute named "subnet_name".
    ╵
    ╷
    │ Error: Unsupported attribute
    │ 
    │   on modules/terraform-azurerm-vnet/main.tf line 104, in resource "azurerm_subnet" "snet":
    │  104:   address_prefixes                               = each.value.subnet_address_prefix
    │     ├────────────────
    │     │ each.value is object with 2 attributes
    │ 
    │ This object does not have an attribute named "subnet_address_prefix".
    ╵
    ╷
    │ Error: Unsupported attribute
    │ 
    │   on modules/terraform-azurerm-vnet/main.tf line 104, in resource "azurerm_subnet" "snet":
    │  104:   address_prefixes                               = each.value.subnet_address_prefix
    │     ├────────────────
    │     │ each.value is object with 2 attributes
    │ 
    │ This object does not have an attribute named "subnet_address_prefix".
    ╵
    ╷
    │ Error: Unsupported attribute
    │ 
    │   on modules/terraform-azurerm-vnet/main.tf line 104, in resource "azurerm_subnet" "snet":
    │  104:   address_prefixes                               = each.value.subnet_address_prefix
    │     ├────────────────
    │     │ each.value is object with 2 attributes
    │ 
    │ This object does not have an attribute named "subnet_address_prefix".
    ╵
    ╷
    │ Error: Unsupported attribute
    │ 
    │   on modules/terraform-azurerm-vnet/main.tf line 104, in resource "azurerm_subnet" "snet":
    │  104:   address_prefixes                               = each.value.subnet_address_prefix
    │     ├────────────────
    │     │ each.value is object with 2 attributes
    │ 
    │ This object does not have an attribute named "subnet_address_prefix".
    ╵
    ```


I receive the following error when creating an AzureBastion Subnet:

```
│Failure sending request: StatusCode=400 -- Original Error: Code="NetworkSecurityGroupNotCompliantForAzureBastionSubnet"
│ 
```

What NSG rules are required to make an Azure Bastion Subnet compliant?


Below is an example of the inbound and outbound rule specification for an NSG used by a terraform module.

```
      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["weballow-0004", "200", "Inbound", "Allow", "Tcp", "443", "*", "0.0.0.0/0"],

      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        ["ntp-out-0005", "150", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
        ["web-insecure-0005", "160", "Outbound", "Allow", "Tcp", "80", "", "0.0.0.0/0"],
      ]
```

Using the above format, create a complete rule configuration for the rules required by an Azure Bastion Subnet NSG.

---

Here is more information on the Engress and Ingress rules required by the AzureBastionSubnet NSG:

---
Ingress Traffic:

Ingress Traffic from public internet: The Azure Bastion will create a public IP that needs port 443 enabled on the public IP for ingress traffic. Port 3389/22 are NOT required to be opened on the AzureBastionSubnet. Note that the source can be either the Internet or a set of public IP addresses that you specify.
Ingress Traffic from Azure Bastion control plane: For control plane connectivity, enable port 443 inbound from GatewayManager service tag. This enables the control plane, that is, Gateway Manager to be able to talk to Azure Bastion.
Ingress Traffic from Azure Bastion data plane: For data plane communication between the underlying components of Azure Bastion, enable ports 8080, 5701 inbound from the VirtualNetwork service tag to the VirtualNetwork service tag. This enables the components of Azure Bastion to talk to each other.
Ingress Traffic from Azure Load Balancer: For health probes, enable port 443 inbound from the AzureLoadBalancer service tag. This enables Azure Load Balancer to detect connectivity
Screenshot shows inbound security rules for Azure Bastion connectivity.

Egress Traffic:

Egress Traffic to target VMs: Azure Bastion will reach the target VMs over private IP. The NSGs need to allow egress traffic to other target VM subnets for port 3389 and 22. If you're utilizing the custom port functionality within the Standard SKU, ensure that NSGs allow outbound traffic to the service tag VirtualNetwork as the destination.
Egress Traffic to Azure Bastion data plane: For data plane communication between the underlying components of Azure Bastion, enable ports 8080, 5701 outbound from the VirtualNetwork service tag to the VirtualNetwork service tag. This enables the components of Azure Bastion to talk to each other.
Egress Traffic to other public endpoints in Azure: Azure Bastion needs to be able to connect to various public endpoints within Azure (for example, for storing diagnostics logs and metering logs). For this reason, Azure Bastion needs outbound to 443 to AzureCloud service tag.
Egress Traffic to Internet: Azure Bastion needs to be able to communicate with the Internet for session, Bastion Shareable Link, and certificate validation. For this reason, we recommend enabling port 80 outbound to the Internet.
---

Update the rule configuration, including any rules not already there.
