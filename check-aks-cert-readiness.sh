#!/bin/bash
#**WARNING** THIS IS AN EXAMPLE CHECK SCRIPT ** YOU NEED TO REVIEW EACH LINE AND CUSTOMISE IT TO YOUR REQUIREMENTS AS THERE ARE HARD CODED ITEMS HERE
# Set error handling
set -e
trap 'handle_error $? $LINENO' ERR

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handler function
handle_error() {
    echo -e "${RED}Error: Script failed at line $2 with exit code $1${NC}"
    echo "FAIL"
    exit 1
}

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        echo "FAIL"
        exit 1
    fi
}

# Function to check cert-manager pods
check_cert_manager() {
    echo -e "${YELLOW}Checking cert-manager pods...${NC}"
    local ready_pods=$(kubectl get pods -n cert-manager -o json | jq -r '.items[] | select(.status.phase == "Running" and (.status.conditions[] | select(.type == "Ready")).status == "True") | .metadata.name' | wc -l)
    local total_pods=$(kubectl get pods -n cert-manager -o json | jq -r '.items | length')
    
    if [ "$ready_pods" -ne "$total_pods" ]; then
        echo -e "${RED}Error: Not all cert-manager pods are ready ($ready_pods/$total_pods)${NC}"
        return 1
    fi
    return 0
}

# Function to check AGIC pods
check_agic() {
    echo -e "${YELLOW}Checking AGIC pods...${NC}"
    local agic_ready=$(kubectl get pods -n kube-system -l app=ingress-appgw -o json | jq -r '.items[] | select(.status.phase == "Running" and (.status.conditions[] | select(.type == "Ready")).status == "True") | .metadata.name' | wc -l)
    
    if [ "$agic_ready" -eq 0 ]; then
        echo -e "${RED}Error: AGIC pod is not ready${NC}"
        return 1
    fi
    return 0
}

# Function to get AKS details
get_aks_details() {
    echo -e "${YELLOW}Getting AKS cluster details...${NC}"
    
    # Check if user is logged into Azure CLI
    if ! az account show &> /dev/null; then
        echo -e "${RED}Error: Not logged into Azure CLI. Please run 'az login' first${NC}"
        return 1
    fi

    # Get current subscription
    local current_sub=$(az account show --query name -o tsv)
    echo -e "${YELLOW}Using subscription: $current_sub${NC}"
    
    # Get the list of AKS clusters in the current subscription
    local aks_list=$(az aks list --query '[0]' -o json)
    if [ -z "$aks_list" ] || [ "$aks_list" == "null" ]; then
        echo -e "${YELLOW}No AKS clusters found in subscription: $current_sub${NC}"
        echo -e "${YELLOW}Skipping remaining checks as no AKS cluster exists${NC}"
        echo -e "${GREEN}Test marked as PASS${NC}"
        echo "OK"
        exit 0  # Exit successfully without running further checks
    fi
    
    # Get cluster name and resource group
    AKS_NAME=$(echo $aks_list | jq -r '.name')
    AKS_RG=$(echo $aks_list | jq -r '.resourceGroup')
    
    # Get credentials for the cluster
    echo -e "${YELLOW}Getting AKS credentials...${NC}"
    if ! az aks get-credentials --name $AKS_NAME --resource-group $AKS_RG --overwrite-existing; then
        echo -e "${RED}Error: Could not get AKS credentials${NC}"
        return 1
    fi
    
    # Verify AKS cluster exists and get its details
    local aks_details=$(az aks show -n $AKS_NAME -g $AKS_RG -o json)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Could not get AKS cluster details${NC}"
        return 1
    fi
    
    # Get the node resource group (MC_* group) where AppGW lives
    NODE_RG=$(echo $aks_details | jq -r .nodeResourceGroup)
    
    # Export variables for use in other functions
    export AKS_NAME
    export AKS_RG
    export NODE_RG
    
    echo -e "${GREEN}Successfully connected to AKS cluster: $AKS_NAME${NC}"
}

# Function to check Application Gateway health
check_appgw() {
    echo -e "${YELLOW}Checking Application Gateway...${NC}"
    
    # Get the Application Gateway name dynamically
    local appgw_name=$(az network application-gateway list -g $NODE_RG --query "[0].name" -o tsv)
    if [ -z "$appgw_name" ]; then
        echo -e "${RED}Error: No Application Gateway found in resource group $NODE_RG${NC}"
        return 1
    fi
    
    if ! az network application-gateway show -n $appgw_name -g $NODE_RG &> /dev/null; then
        echo -e "${RED}Error: Application Gateway not found or not accessible${NC}"
        return 1
    fi
    
    local operational_state=$(az network application-gateway show -n $appgw_name -g $NODE_RG --query 'operationalState' -o tsv)
    if [ "$operational_state" != "Running" ]; then
        echo -e "${RED}Error: Application Gateway is not in Running state (Current state: $operational_state)${NC}"
        return 1
    fi
    return 0
}

# Function to check and install kubelogin
check_kubelogin() {
    echo -e "${YELLOW}Checking kubelogin installation...${NC}"
    
    # Create local bin directory in user's home if it doesn't exist
    LOCAL_BIN="$HOME/.local/bin"
    mkdir -p "$LOCAL_BIN"
    
    # Add local bin to PATH if not already there
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        export PATH="$LOCAL_BIN:$PATH"
    fi
    
    if ! command -v kubelogin &> /dev/null; then
        echo -e "${YELLOW}kubelogin not found. Installing to $LOCAL_BIN...${NC}"
        
        # Download and install kubelogin using az aks install-cli with custom location
        if ! az aks install-cli --install-location "$LOCAL_BIN/kubectl" --kubelogin-install-location "$LOCAL_BIN/kubelogin"; then
            echo -e "${RED}Error: Failed to install kubectl and kubelogin${NC}"
            return 1
        fi
        
        # Verify kubelogin was installed
        if ! command -v kubelogin &> /dev/null; then
            echo -e "${RED}Error: kubelogin installation failed${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}kubelogin is installed${NC}"
    return 0
}

# Main execution
main() {
    echo -e "${YELLOW}Starting pre-flight checks...${NC}"
    
    # Check required commands
    echo -e "${YELLOW}Checking required commands...${NC}"
    check_command "kubectl"
    check_command "az"
    check_command "jq"
    
    # Check and install kubelogin
    check_kubelogin || { echo "FAIL"; exit 1; }
    
    # Get AKS cluster details
    get_aks_details || { echo "FAIL"; exit 1; }

    # basic cluster access checks
    printf "listing kubernetes namespaces ...\n"
    kubectl get ns
    
    # Check if we can access the cluster
    echo -e "${YELLOW}Checking cluster access...${NC}"
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot access Kubernetes cluster${NC}"
        echo "FAIL"
        exit 1
    fi
    
    # Run component checks
    check_cert_manager || { echo "FAIL"; exit 1; }
    check_agic || { echo "FAIL"; exit 1; }
    check_appgw || { echo "FAIL"; exit 1; }
    
    # All checks passed
    echo -e "${GREEN}All pre-flight checks passed${NC}"
    echo "OK"
}

# Run main function
main 
