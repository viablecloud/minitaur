# Self-Contained, Minimal Azure Cloud Foundations for Small to Medium Enterprise and Startups

This repository provides infrastructure as code implementation and a containerised deployer to deliver a complete cloud operating environment with these infrastructure features:

* 1. Single Subscription Layout: single primary subscription. Optional additional subscriptions
* 2. Virtual Networking: VNET, default subnet layout, application gateway (optional), private DNS for internal names
* 3. Storage: NFS, CIFS, Blob storage account, centralised
* 4. Compute: Single containerisation server with dockerised components
* 5. Secrets Vault: Secure Keyvault for storage and retrieval of keyvaults
* 6. O.S Image Management: Azure Container Registry

![alt text](media/minitaur-cloud-foundations.png?raw=true "The Deployed Cloud Environment") 

The code may be used to quickly bootstrap new business I.T infrastructure in the cloud and used as a starting point to expand and enhance your cloud architecture. 

# Why Minitaur?

* At the current pace of technological change and blistering speed of the global economy your business has no time to spends months building out a complete cloud operating environment including fully secured landing zones and compliance. You need to hit the ground running with your MVP and go to market like "yesterday" if you want to make the best use of your VC runway.
* Minitaur gives you a tried, tested, well thought-out installation of a complete cloud operating environment in the form of understandable infrastructure code. You can get your applications running immediately on a stable cloud foundation and evolve the architecture at your leisure.
* No need for weeks or months of consultancy and contractor time. Run the deployment, access the environment, deploy your apps using your usual methods and go to market!

# Available infrastructure modules

* By default the following minimal set of modules are included. These provide the very basics required to automate  a clean, functional cloud environment:

```bash
(base) minitaur@Minitaurs-iMac minitaur % ls -l modules 
total 8
drwxr-xr-x   3 minitaur  staff    96 Nov 30 22:29 acr-private ... private internal Container registry for container image builds
drwxr-xr-x   3 minitaur  staff    96 Nov 30 22:29 app_gw ... An application gateway for exposing microservices to the internet
drwxr-xr-x   3 minitaur  staff    96 Nov 30 22:29 app_gw_nsg ... Application Gateway Network Security Group
drwxr-xr-x  34 minitaur  staff  1088 Jan 26 14:21 avm-aks-7.3.0 ... Azure Kubernetes service (Using the Azure Verified Module)
drwxr-xr-x   4 minitaur  staff   128 Nov 30 22:29 bastion ... Bastion Service for connecting via portal to VMs
drwxr-xr-x   3 minitaur  staff    96 Nov 30 22:29 compute-linux ... Linux VM
drwxr-xr-x   4 minitaur  staff   128 Nov 30 22:29 kv-private ... Private Keyvault
drwxr-xr-x  10 minitaur  staff   320 Feb  3 16:46 terraform-azurerm-vnet ...Azure VNET
```

* The default architecture deployed with minitaur consumes all these modules and makes these infrastructure components available to you.


# How to Use this Codebase

## Assumptions and Pre-requisites
## Customise the basics
## Start up the deployer
## Test the code base (Dry Run)
## Run the deployer pipeline
## Address any deploy issues  

# Next Steps

* Reach out to ViableCloud.com for more advice on how to create a complete enterprise-grade landing zone implementation with multi-subscription, multi-tenant and multi-region support.
