#!/bin/bash

#set -euo pipefail
set -x

# Function to print usage
print_usage() {
    echo "Usage: $0 <path-to-exclude-list>"
    echo "The exclude list file should contain one resource group name per line"
    exit 1
}

# Check if exclude list file is provided
if [ $# -ne 1 ]; then
    print_usage
fi

EXCLUDE_FILE="$1"
TIMEOUT_SECONDS=300  # 5 minutes
declare -A DESTROYED_RESOURCES
declare -a FAILED_RESOURCES

# Validate exclude file exists
if [ ! -f "$EXCLUDE_FILE" ]; then
    echo "Error: Exclude list file not found: $EXCLUDE_FILE"
    exit 1
fi

# Load exclude list into array
mapfile -t EXCLUDED_RGS < "$EXCLUDE_FILE"

# Function to check if resource group is in exclude list
is_excluded() {
    local rg="$1"
    for excluded in "${EXCLUDED_RGS[@]}"; do
        if [ "$rg" == "$excluded" ]; then
            return 0
        fi
    done
    return 1
}

# Function to wait for resource deletion with timeout
wait_for_deletion() {
    local resource_id="$1"
    local start_time
    start_time=$(date +%s)

    while true; do
        if ! az resource show --ids "$resource_id" &>/dev/null; then
            return 0
        fi

        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $TIMEOUT_SECONDS ]; then
            echo "Timeout waiting for resource deletion: $resource_id"
            return 1
        fi

        sleep 10
    done
}

# Counter variables
total_destroyed=0
total_failed=0
total_empty_rgs=0

# Get all subscriptions
echo "Discovering subscriptions..."
readarray -t subscriptions < <(az account list --query '[].{id:id}[]' -o tsv)

if [ ${#subscriptions[@]} -eq 0 ]; then
    echo "Error: No subscriptions found. Please check your Azure login status."
    exit 1
fi

echo "Found ${#subscriptions[@]} subscriptions"

# Debug: Print all found subscriptions
echo "Subscriptions to process:"
printf '%s\n' "${subscriptions[@]}"

# Iterate through each subscription
for subscription in "${subscriptions[@]}"; do
    # Skip empty subscription IDs
    if [ -z "$subscription" ]; then
        echo "Skipping empty subscription ID"
        continue
    fi
    
    echo -e "\n=== Processing subscription: $subscription ==="
    if ! az account set --subscription "$subscription"; then
        echo "Warning: Failed to switch to subscription: $subscription. Skipping..."
        continue
    fi

    # Get all resource groups
    echo "Discovering resource groups in subscription $subscription..."
    readarray -t resource_groups < <(az group list --query '[].name' -o tsv)

    if [ ${#resource_groups[@]} -eq 0 ]; then
        echo "No resource groups found in subscription: $subscription"
        continue
    fi

    echo "Found ${#resource_groups[@]} resource groups in subscription $subscription"

    # Iterate through each resource group
    for rg in "${resource_groups[@]}"; do
        # Skip if resource group is in exclude list
        if is_excluded "$rg"; then
            echo "Skipping excluded resource group: $rg"
            continue
        fi

        echo "Processing resource group: $rg"
        
        # Get all resources in the resource group
        mapfile -t resources < <(az resource list \
            --resource-group "$rg" \
            --query '[].{id:id, name:name}' \
            -o tsv)

        if [ ${#resources[@]} -eq 0 ]; then
            echo "Resource group is empty: $rg"
            ((total_empty_rgs++))
            
            echo "Attempting to delete empty resource group: $rg"
            #if az group delete --name "$rg" --yes --no-wait &>/dev/null; then
            #    DESTROYED_RESOURCES["$rg,<empty-group>"]=true
            #    ((total_destroyed++))
            #    echo "Successfully initiated deletion of empty resource group: $rg"
            #else
            #    DESTROYED_RESOURCES["$rg,<empty-group>"]=false
            #    FAILED_RESOURCES+=("$rg")
            #    ((total_failed++))
            #    echo "Failed to delete empty resource group: $rg"
            #fi
            continue
        fi

        # Iterate through each resource
        while IFS=$'\t' read -r resource_id resource_name; do
            # Skip if resource_id is empty
            if [ -z "$resource_id" ]; then
                continue
            fi
            
            echo "Attempting to delete resource: $resource_name"
            
            #if az resource delete --ids "$resource_id" --force true &>/dev/null; then
            #    if wait_for_deletion "$resource_id"; then
            #        DESTROYED_RESOURCES["$rg,$resource_name"]=true
            #        ((total_destroyed++))
            #        echo "Successfully deleted: $resource_name"
            #    else
            #        DESTROYED_RESOURCES["$rg,$resource_name"]=false
            #        FAILED_RESOURCES+=("$resource_id")
            #        ((total_failed++))
            #        echo "Failed to confirm deletion of: $resource_name"
            #    fi
            #else
            #    DESTROYED_RESOURCES["$rg,$resource_name"]=false
            #    FAILED_RESOURCES+=("$resource_id")
            #    ((total_failed++))
            #    echo "Failed to delete: $resource_name"
            #fi
        done < <(printf '%s\n' "${resources[@]}")
    done
done

# Print summary
echo -e "\n=== Destruction Summary ==="
echo "Empty Resource Groups found: $total_empty_rgs"
echo "Resource Status:"
for key in "${!DESTROYED_RESOURCES[@]}"; do
    IFS=',' read -r rg resource <<< "$key"
    echo "[$rg], [$resource], [destroy succeeded=${DESTROYED_RESOURCES[$key]}]"
done

echo -e "\nFailed Resources:"
for resource_id in "${FAILED_RESOURCES[@]}"; do
    echo "[$resource_id]"
done

echo -e "\nFinal Summary:"
echo "Total empty resource groups found: $total_empty_rgs"
echo "Total resources destroyed successfully: $total_destroyed"
echo "Total resources failed to destroy: $total_failed" 
