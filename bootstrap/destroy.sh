#!/bin/bash

set -euo pipefail

#Configure level and state sources
source ../env.sh

# Validate required environment variables
required_vars=("organisation_name" "lzCode" "primary_location")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: Required environment variable $var is not set"
        exit 1
    fi
done

# Configure storage account name and ensure organisation_name is lowercase
# Storage account name uses no special characters
storage_account_name="${organisation_name,,}${lzCode}${DEPLOYMENT_LOCATION_SHORT}bootstrap"
# Resource group name keeps the hyphens
resource_group_name="${organisation_name,,}-${lzCode}-bootstrap"

# Check if storage account exists
if az storage account show --name "$storage_account_name" --resource-group "$resource_group_name" &>/dev/null; then
    echo "Deleting storage account: $storage_account_name"
    az storage account delete \
        --name "$storage_account_name" \
        --resource-group "$resource_group_name" \
        --yes
else
    echo "Storage account $storage_account_name does not exist"
fi

# Check if resource group exists and delete it
if az group show --name "$resource_group_name" &>/dev/null; then
    echo "Deleting resource group: $resource_group_name"
    az group delete \
        --name "$resource_group_name" \
        --yes
else
    echo "Resource group $resource_group_name does not exist"
fi

echo "Storage account and resource group deletion completed successfully" 
