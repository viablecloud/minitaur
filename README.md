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

* For step-by-step deployment guide, refer to this wiki page: https://github.com/viablecloud/minitaur/wiki/Minitaur-Azure-Deployment-Guide
* For anarchitecture overview, refer to this wiki page: 

## Assumptions and Pre-requisites

* An unused Azure Cloud Tenant with at least one subscription available
* An Azure cloud login user with Global Tenant Owner permissions
* Rancher Desktop, Minikube or Docker Desktop installed on your deployment workstation
* A github account

## Customise the basics

* Configure the infrastructure code using a few parameters in a central configuration file (`lz000.conf` and `deployer.conf`).
* Below are the minimum parameters you should configure:

* lz000.conf

```
TENANT_ID=your-azure-tenant-id
TENANT_ORGANISATION_NAME=vc
TENANT_ORGANISATION_SHORT=vc
MANAGEMENT_SUBSCRIPTION_ID=your-target-azure-subscription-id
DEPLOYMENT_LOCATION_SHORT=ea
PRIMARY_LOCATION=eastasia
APP_OWNER_EMAIL=tgw@viablecloud.io
AUTHORISED_DEPLOYERS="your-deployer-worksatation-public-address"
AzureSubscription=your-target-azure-subscription-id
```

* deployer.yaml

```
.
.
.
        - name: ORG_REPO_SPACE
          value: "your github org namespace"
        - name: GIT_REPO
          value: "minitaur"
.
.
.
data:
  username: "base64 encoded github username" 
  token: "base64 encoded github token"
```

* Note: Commit these changes to your github repo, they'll be pulled by the minitaur ci/cd deployer

## Start up the deployer

* To run on kubernetes (e.g Rancher Desktop): 

```
cd deployer/deployer-image 
./deploy.sh
kubectl get pods -n minitaur
```

## Test the code base (Dry Run)

* See wiki guide: https://github.com/viablecloud/minitaur/wiki/Minitaur-Azure-Deployment-Guide#7-login-to-jenkins-and-run-the-bootstrap-pipeline-create-remote-state-storage 

## Run the deployer pipeline

* See wiki guide: https://github.com/viablecloud/minitaur/wiki/Minitaur-Azure-Deployment-Guide#7-login-to-jenkins-and-run-the-bootstrap-pipeline-create-remote-state-storage 

## Address any deploy issues  

* Log any deployment issues with our support team here: https://github.com/viablecloud/minitaur/issues 

# Next Steps

* Reach out to ViableCloud.com for more advice on how to create a complete enterprise-grade landing zone implementation with multi-subscription, multi-tenant and multi-region support.
* You can reach us at https://viablecloud.io/ or directly via email: matt at viablecloud dot io 
