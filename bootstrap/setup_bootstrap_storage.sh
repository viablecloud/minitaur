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
container_name="bootstrap"
# Resource group name keeps the hyphens
resource_group_name="${organisation_name,,}-${lzCode}-bootstrap"

# Function to enable public network access
enable_public_access() {
    echo "Enabling public network access..."
    az storage account update \
        --name "$storage_account_name" \
        --resource-group "$resource_group_name" \
        --default-action Allow \
        --bypass AzureServices
}

# Function to get deployer IP address
get_deployer_ip() {
    printf "** Getting deployer IP address... **\n"
    # Try curl first
    deployer_ip=$(curl -s http://ifconfig.co)
    
    # If curl fails, use environment variable
    if [[ -z "$deployer_ip" ]]; then
        deployer_ip="$AUTHORISED_DEPLOYERS"
    fi
    
    if [[ -z "$deployer_ip" ]]; then
        echo "Error: Could not determine deployer IP address"
        exit 1
    fi
    echo "$deployer_ip"
}

# Function to disable public network access but allow deployer IP
disable_public_access() {
    local deployer_ip
    deployer_ip=$(get_deployer_ip)
    
    echo "Disabling public network access but allowing $deployer_ip..."
    az storage account update \
        --name "$storage_account_name" \
        --resource-group "$resource_group_name" \
        --default-action Deny \
        --bypass AzureServices

    # Add deployer IP to allowed list
    printf "Adding deployer IP ${deployer_ip} to allowed list ... \n"
    az storage account network-rule add \
        --resource-group "$resource_group_name" \
        --account-name "$storage_account_name" \
        --ip-address "$deployer_ip"
}

# Cleanup function to ensure public access is disabled on script exit
cleanup() {
    if az storage account show --name "$storage_account_name" --resource-group "$resource_group_name" &>/dev/null; then
        disable_public_access
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Create resource group if it doesn't exist
if ! az group show --name "$resource_group_name" &>/dev/null; then
    echo "Creating resource group: $resource_group_name"
    az group create \
        --name "$resource_group_name" \
        --location "$primary_location"
fi

# Create storage account if it doesn't exist
if ! az storage account show --name "$storage_account_name" --resource-group "$resource_group_name" &>/dev/null; then
    echo "Creating storage account: $storage_account_name"
    az storage account create \
        --name "$storage_account_name" \
        --resource-group "$resource_group_name" \
        --location "$primary_location" \
        --sku Standard_LRS \
        --kind StorageV2
fi

# Now that we know the storage account exists, enable public access
enable_public_access

# Add a small delay to allow network rule changes to propagate
echo "Waiting for network rules to propagate..."
sleep 30

# Get storage account key
account_key=$(az storage account keys list \
    --resource-group "$resource_group_name" \
    --account-name "$storage_account_name" \
    --query '[0].value' \
    --output tsv)

# Create container if it doesn't exist
if ! az storage container show \
    --name "$container_name" \
    --account-name "$storage_account_name" \
    --account-key "$account_key" &>/dev/null; then
    echo "Creating container: $container_name"
    az storage container create \
        --name "$container_name" \
        --account-name "$storage_account_name" \
        --account-key "$account_key"
fi

# Add a small delay before disabling public access
echo "Waiting before disabling public access..."
sleep 10

echo "Storage account setup completed successfully"
