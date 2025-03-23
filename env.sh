#!/bin/bash
set -ex
#NOTE: These values should be passed from the pipeline environment. This env script is for manual bootstrapping and reference.
#one env.sh per level
#NOTE: this should match what's configured in bootstrap/variables.tf
#Configure key parts of the naming convention for this deployment (should be unique per tenant)
#naming convention is used to access state storage resources as in this example
#by scripts
#

#intialisation of deployment accounts
export management_account_id="${MANAGEMENT_SUBSCRIPTION_ID}"

#one could infer this from the directory structure, but let's be explicit ...
export level="l1"
export environment="${TENANT_ENVIRONMENT_DOMAIN}"

export primary_location="${PRIMARY_LOCATION}"
export org_short="${TENANT_ORGANISATION_SHORT}"
export organisation_id="${org_short}"
export organisation_name="${TENANT_ORGANISATION_NAME}"
export homeTenantId="${TENANT_ID}"
export root_parent_id="${homeTenantId}"
export root_id="${organisation_id}"
export root_name="${organisation_name}"
export location_short="${DEPLOYMENT_LOCATION_SHORT}"
export deploy_index="${TENANT_DEPLOY_INDEX}"
export billing_account="na"
export billing_profile="na"

#For terraform
export TF_VAR_subscription_id_management="${MANAGEMENT_SUBSCRIPTION_ID}"
export TF_VAR_primary_location="${primary_location}"
export TF_VAR_primary_region="${location_short}"
export TF_VAR_environment="${environment}"
export TF_VAR_deploy_index="${deploy_index}"

#Infrastructure Ownership details
export app_owner="${APP_OWNER}"
export app_owner_email="${APP_OWNER_EMAIL}"
export cost_center="${COST_CENTER}"
export TF_VAR_app_owner="${app_owner}"
export TF_VAR_app_owner_email="${app_owner_email}"
export TF_VAR_cost_center="${cost_center}"
