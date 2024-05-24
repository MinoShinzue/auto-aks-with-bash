#!/bin/bash

# Check if the script is running as root
if [ "$(id -u)" != "0" ]; then
    echo "Please run this script as root."
    sudo bash "$0" "$@"
    exit $?
fi

# Check system architecture
architecture=$(uname -m)
if [ "$architecture" == "x86_64" ]; then
    installPath="/usr/local/bin"
    downloadUri="https://aka.ms/installazurecliwindows"
elif [ "$architecture" == "i686" ]; then
    installPath="/usr/local/bin"
    downloadUri="https://aka.ms/installazurecliwindows"
else
    echo "Unsupported architecture: $architecture."
    exit 1
fi

# Define log file path
logFilePath="./log/InstallAzureCLI.log"

# Check if Azure CLI is already installed
if [ ! -x "$installPath/az" ]; then
    # Check if Azure CLI MSI already exists
    if [ ! -f "./AzureCLI.msi" ]; then
        # Download Azure CLI MSI
        echo "Downloading Azure CLI MSI..."
        curl -o "./AzureCLI.msi" "$downloadUri"
    else
        echo "Azure CLI MSI already exists."
    fi

    # Install Azure CLI
    echo "Installing Azure CLI..."
    wine msiexec.exe /i ./AzureCLI.msi /quiet /qn /norestart 2>> "$logFilePath"
    echo "Azure CLI installation completed successfully."
        
    # Add Azure CLI to the PATH environment variable
    if [[ ":$PATH:" != *":$installPath:"* ]]; then
        echo "Adding Azure CLI to PATH..."
        echo "export PATH=\"$installPath:\$PATH\"" >> ~/.bashrc
        source ~/.bashrc
        echo "Azure CLI added to PATH successfully."
    else
        echo "Azure CLI is already in the PATH."
    fi

    # Delete Azure CLI MSI file
    rm -f "./AzureCLI.msi"
else
    echo "Azure CLI is already installed."
fi
