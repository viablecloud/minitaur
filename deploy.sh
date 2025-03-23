#!/bin/bash
#deployment wrapper for terraform Azure AD Management Module
set -ex

function debug_app_gw () {
   kubectl logs -n kube-system -l app=ingress-appgw --tail=100
   ./debug_agic.sh
   terraform output app_gateway_config
   terraform output ingress_config
}


function registerProviders () {
   az provider register --namespace 'Microsoft.TimeSeriesInsights'
}

function setAccount () {
   echo "setting management account for deployment ... ${management_account_id}"
   az account set --subscription ${management_account_id}
   az account list -o table
}

function terraformInit () {
        printf "Generating backend configuration ...\n"
        terraform fmt
      # Run the terraform init command with inline backend configuration
terraform init \
  -backend-config="storage_account_name=${storage_account_name}" \
  -backend-config="resource_group_name=${resource_group_name}" \
  -backend-config="container_name=${container_name}" \
  -backend-config="key=${blob_name}"
}

function terraformPlan() {
        #IDEA: we could perhaps store the plan as an artifact (versioned) before applying it
        terraform plan \
          -var management_subscription_id="${MANAGEMENT_SUBSCRIPTION_ID}" \
          -var location_short=${location_short} \
          -var tenant_id=${tenant_id} \
          -var owner=${app_owner} \
          -var deployment_environment=${environment} \
          -out terraform.plan

        echo "planning: terraform plan -var ... -out terraform.plan"
}

function loginToTenant() {
 #handle special login requirements for Azure AD management
  az logout
  az login --allow-no-subscriptions --tenant ${TENANT_ID}
}

function terraformApply() {
        echo "Running terraform apply ..."
	terraform apply terraform.plan
}

function terraformStateList () {
	terraform state list
}

function cleanupTerraform () {
        printf "cleaning up stale terraform residue ...\n"
	rm -rf .terraform
	rm -rf terraform.plan
}


#Configure level and state sources
source ./env.sh
# Configure storage account name and ensure organisation_name is lowercase
# Storage account name uses no special characters
storage_account_name="${organisation_name,,}${lzCode}${DEPLOYMENT_LOCATION_SHORT}bootstrap"
# Resource group name keeps the hyphens
resource_group_name="${organisation_name,,}-${lzCode}-bootstrap"
container_name="bootstrap" #Better to use a naming convention "${organisation_name,,}-${lzCode}-${lzCode}"
blob_name="${organisation_name,,}-${lzCode}-bootstrap"

#0) authenticate
#loginToTenant

#1) set subscription
setAccount

#2) initialise 
terraformInit

#3) terraform plan
terraformPlan

#4) terraform  apply
terraformApply

#5) Show what was done
terraformStateList

#6) clean up ...
#probably just delete the old plans, .terraform dirs etc ...
cleanupTerraform

#optional debug step
#debug_app_gw

