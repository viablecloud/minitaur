# Core Infrastructure Modules for Minitaur

**WARNING**
No need to look in here if you wish to preserve your sanity.
Just refer to the main terraform "root module* files in the directory above this one
**/WARNING**

**WARNING: WARRANTY VOID IF OPENED**

*The following modules are used to build the foundation for the Azure cloud environment*

* terraform-azurerm-vnet: VNET definition and network layout
* compute-linux: Linux Server module
* bastion: Bastion service to connect securely to servers
* kv-private: Keyvault to hold server access credentials (and all other optional secrets)
* acr-private: Azure container registry for private container image storage
* avm-aks-7.3.0: Azure Kubernetes service module
* app_gw: Application Gateway for exposing your applications outbound
* app_gw_nsg: Network Security Groups for Securing application gateway
