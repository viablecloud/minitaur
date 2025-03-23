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

# Function to get deployer IP address
get_deployer_ip() {
    local deployer_ip
    
    # Try to get IP from curl
    if deployer_ip=$(curl -s http://ifconfig.co); then
        echo "$deployer_ip"
        return 0
    fi
    
    # Fallback to environment variable
    if [[ -n "${AUTHORISED_DEPLOYERS:-}" ]]; then
        echo "$AUTHORISED_DEPLOYERS"
        return 0
    fi
    
    echo "Error: Could not determine deployer IP address" >&2
    return 1
}

# Function to enable restricted network access
enable_restricted_access() {
    local deployer_ip
    deployer_ip=$(get_deployer_ip) || exit 1
    
    echo "Enabling restricted network access (allowing only $deployer_ip)..."
    # First set the default action to deny all
    az storage account update \
        --name "$storage_account_name" \
        --resource-group "$resource_group_name" \
        --default-action Deny \
        --bypass AzureServices

    # Then add the deployer IP to allowed list
    az storage account network-rule add \
        --resource-group "$resource_group_name" \
        --account-name "$storage_account_name" \
        --ip-address "$deployer_ip"
}

# Modify cleanup function to just ensure restricted access is maintained
cleanup() {
    if az storage account show --name "$storage_account_name" --resource-group "$resource_group_name" &>/dev/null; then
        enable_restricted_access
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

# Now that we know the storage account exists, enable restricted access
enable_restricted_access

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

# Before script exits, instead of completely disabling access,
# ensure the deployer IP remains allowed
echo "Ensuring storage account remains accessible to deployer..."
enable_restricted_access

echo "Storage account setup completed successfully"
