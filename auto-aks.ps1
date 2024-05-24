# Function to install Azure CLI on Windows
function install_azure_cli_windows {
    # Call the PowerShell script to install Azure CLI on Windows
    Write-Host "Running Azure CLI installation script for Windows..."
    powershell.exe -ExecutionPolicy Bypass -File "./tools/install_az_windows.ps1"
}

# Function to install Azure CLI on Linux
function install_azure_cli_linux {
    # Call the script to install Azure CLI on Linux
    Write-Host "Running Azure CLI installation script for Linux..."
    ./tools/install_az_linux.sh
}

# Check if az command exists
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI (az) is not installed. Proceeding with installation..."
    
    # Check the operating system
    if ($env:OSTYPE -like "linux-gnu*") {
        install_azure_cli_linux
    }
    elseif ($env:OSTYPE -like "darwin*") {
        Write-Host "This script does not support macOS."
        exit 1
    }
    elseif ($env:OSTYPE -like "msys" -or $env:OSTYPE -like "cygwin") {
        install_azure_cli_windows
    }
    else {
        Write-Host "Unsupported operating system."
        exit 1
    }
}

# Check if logged in
if (-not (az account show)) {
    Write-Host "You are not logged in to Azure. Logging in..."
    az login
}
else {
    Write-Host "You are already logged in to Azure."
}

# Function to find the most relevant location based on user input
function find_most_relevant_location {
    param(
        [string]$user_input
    )

    $relevant_location = ""

    foreach ($location in $locations) {
        # Convert both user input and location to lowercase and remove spaces for case-insensitive comparison
        $user_input_lc = $user_input -replace '\s', '' -replace '\P{L}', '' -replace '([A-Z])', '$1'
        $location_lc = $location -replace '\s', '' -replace '\P{L}', '' -replace '([A-Z])', '$1'

        # Check if the location contains the user input
        if ($location_lc -like "*$user_input_lc*") {
            $relevant_location = $location
            break
        }
    }

    return $relevant_location
}

# Get list of available locations from Azure CLI
$locations = (az account list-locations --query '[].name' -o tsv)

# Prompt user for Azure Resource Group
$resource_group_name = Read-Host "Enter Azure Resource Group Name"

# Prompt user for Azure Location
$user_location = Read-Host "Enter Azure Location"

# Find the most relevant location
$location = find_most_relevant_location -user_input $user_location

# Check if a relevant location is found
while (-not $location) {
    Write-Host "No relevant location found. Please enter a valid location."
    
    # Print the list of available locations
    Write-Host "Available locations:"
    foreach ($loc in $locations) {
        Write-Host $loc
    }
    
    $user_location = Read-Host "Enter Azure Location"
    $location = find_most_relevant_location -user_input $user_location
}

# Prompt user for AKS Cluster Name
$cluster_name = Read-Host "Enter AKS Cluster Name"

# Prompt the user for node count
$node_count = Read-Host "Enter the number of nodes for the AKS cluster (min 1)"

# Check if the AKS cluster already exists
$existing_cluster = (az aks show --resource-group $resource_group_name --name $cluster_name -o json | ConvertFrom-Json -ErrorAction SilentlyContinue)

# If the cluster already exists, inform the user and exit
if ($existing_cluster) {
    Write-Host "AKS cluster '$cluster_name' already exists in resource group '$resource_group_name'."
    exit 1
}

# Get list of subscriptions
$subscriptions = (az account list --query '[].{Name:name, ID:id}' -o table)

# Display available subscriptions
Write-Host "Available Subscriptions:"
Write-Host $subscriptions

# Prompt user to choose a subscription
$subscription_id = Read-Host "Enter Subscription ID"

# Set chosen subscription
az account set --subscription $subscription_id

# Check if the resource group already exists
$existing_resource_group = (az group exists --name $resource_group_name)

if (-not $existing_resource_group) {
    # Create a resource group
    az group create --name $resource_group_name --location $location
}
else {
    Write-Host "Resource group '$resource_group_name' already exists."
}

# Function to print all available options for AKS creation command
function print_available_options {
    Write-Host "Available options for AKS creation command:"
    az aks create --help | Select-String '^\s*--' | ForEach-Object { $_ -replace '\s.*$' }
}

# Prompt the user to confirm if they want to customize the AKS creation command
$customize_command = Read-Host "Do you want to customize the AKS creation command? (yes/no)"

if ($customize_command -eq "yes") {
    # Print available options
    print_available_options
    
    # Prompt the user to enter additional options for the AKS creation command
    $additional_options = Read-Host "Enter additional options for the AKS creation command (e.g., --option1 value1 --option2 value2)"
    
    # Execute the customized command
    Write-Host "Executing customized AKS creation command..."
    az aks create --resource-group $resource_group_name --name $cluster_name --node-count $node_count --enable-managed-identity --generate-ssh-keys $additional_options
}
else {
    # Execute the default AKS creation command
    Write-Host "Executing default AKS creation command..."
    az aks create --resource-group $resource_group_name --name $cluster_name --node-count $node_count --enable-managed-identity --generate-ssh-keys
}

# Get AKS credentials
az aks get-credentials --resource-group $resource_group_name --name $cluster_name

# Verify AKS cluster
kubectl get nodes
