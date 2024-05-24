#!/bin/bash

# Function to install Azure CLI on Windows
install_azure_cli_windows() {
    # Call the PowerShell script to install Azure CLI on Windows
    echo "Running Azure CLI installation script for Windows..."
    powershell.exe -ExecutionPolicy Bypass -File "./tools/install_az_windows.ps1"
}

# Function to install Azure CLI on Linux
install_azure_cli_linux() {
    # Call the script to install Azure CLI on Linux
    echo "Running Azure CLI installation script for Linux..."
    ./tools/install_az_linux.sh
}

# Check if az command exists
if ! command -v az &> /dev/null; then
    echo "Azure CLI (az) is not installed. Proceeding with installation..."
    
    # Check the operating system
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        install_azure_cli_linux
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "This script does not support macOS."
        exit 1
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        install_azure_cli_windows
    else
        echo "Unsupported operating system."
        exit 1
    fi
fi

# Check if logged in
if ! az account show &> /dev/null; then
    echo "You are not logged in to Azure. Logging in..."
    az login
else
    echo "You are already logged in to Azure."
fi

# Function to find the most relevant location based on user input
find_most_relevant_location() {
    user_input=$1
    relevant_location=""

    for location in $locations; do
        # Convert both user input and location to lowercase and remove spaces for case-insensitive comparison
        user_input_lc=$(echo "$user_input" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        location_lc=$(echo "$location" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

        # Check if the location contains the user input
        if [[ "$location_lc" == *"$user_input_lc"* ]]; then
            relevant_location=$location
            break
        fi
    done

    echo "$relevant_location"
}

# Get list of available locations from Azure CLI
locations=$(az account list-locations --query '[].name' -o tsv)

# Prompt user for Azure Resource Group
read -p "Enter Azure Resource Group Name: " resource_group_name

# Prompt user for Azure Location
read -p "Enter Azure Location: " user_location

# Find the most relevant location
location=$(find_most_relevant_location "$user_location")

# Check if a relevant location is found
while [ -z "$location" ]; do
    echo "No relevant location found. Please enter a valid location."
    
    # Print the list of available locations
    echo "Available locations:"
    printf '%s\n' "${locations[@]}"
    
    read -p "Enter Azure Location: " user_location
    location=$(find_most_relevant_location "$user_location")
done

# Prompt user for AKS Cluster Name
read -p "Enter AKS Cluster Name: " cluster_name
# Prompt the user for node count
read -p "Enter the number of nodes for the AKS cluster (min 1): " node_count

# Check if the AKS cluster already exists
existing_cluster=$(az aks show --resource-group $resource_group_name --name $cluster_name &> /dev/null && echo "true" || echo "false")

# If the cluster already exists, inform the user and exit
if [ "$existing_cluster" == "true" ]; then
    echo "AKS cluster '$cluster_name' already exists in resource group '$resource_group_name'."
    exit 1
fi

# Get list of subscriptions
subscriptions=$(az account list --query '[].{Name:name, ID:id}' -o table)

# Display available subscriptions
echo "Available Subscriptions:"
echo "$subscriptions"

# Prompt user to choose a subscription
read -p "Enter Subscription ID: " subscription_id

# # Set chosen subscription
az account set --subscription $subscription_id

# Check if the resource group already exists
existing_resource_group=$(az group exists --name $resource_group_name)

if [ $existing_resource_group == "false" ]; then
    # Create a resource group
    az group create --name $resource_group_name --location $location
else
    echo "Resource group '$resource_group_name' already exists."
fi

# Function to print all available options for AKS creation command
print_available_options() {
    echo "Available options for AKS creation command:"
    az aks create --help | grep -E '^\s*--' | awk '{print $1}'
}

# Prompt the user to confirm if they want to customize the AKS creation command
read -p "Do you want to customize the AKS creation command? (yes/no): " customize_command

if [ "$customize_command" == "yes" ]; then
    # Print available options
    print_available_options
    
    # Prompt the user to enter additional options for the AKS creation command
    read -p "Enter additional options for the AKS creation command (e.g., --option1 value1 --option2 value2): " additional_options
    
    # Execute the customized command
    echo "Executing customized AKS creation command..."
    az aks create --resource-group $resource_group_name --name $cluster_name --node-count $node_count --enable-managed-identity --generate-ssh-keys $additional_options
else
    # Execute the default AKS creation command
    echo "Executing default AKS creation command..."
    az aks create --resource-group $resource_group_name --name $cluster_name --node-count $node_count --enable-managed-identity --generate-ssh-keys
fi

# Get AKS credentials
az aks get-credentials --resource-group $resource_group_name --name $cluster_name

# Verify AKS cluster
kubectl get nodes
