# Check if the script is running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as an administrator."
    $arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

# Set execution policy to RemoteSigned
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

# Check system architecture
$architecture = (Get-WmiObject -Class Win32_Processor).AddressWidth
if ($architecture -eq 32) {
    $installPath = "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2\wbin"
    $downloadUri = "https://aka.ms/installazurecliwindows"
} elseif ($architecture -eq 64) {
    $installPath = "$env:ProgramFiles (x86)\Microsoft SDKs\Azure\CLI2\wbin"
    $downloadUri = "https://aka.ms/installazurecliwindows"
} else {
    Write-Host "Unsupported architecture: $architecture-bit."
    exit
}

# Define log file path
$logFilePath = "./log/InstallAzureCLI.log"

# Function to log error messages
function Log-Error {
    param(
        [string]$errorMessage
    )
    $errorMessage | Out-File -FilePath $logFilePath -Append
}

# Check if Azure CLI is already installed
if (-not (Test-Path "$installPath\az.cmd")) {
    # Check if Azure CLI MSI already exists
    if (-not (Test-Path ".\AzureCLI.msi")) {
        # Download Azure CLI MSI
        Write-Host "Downloading Azure CLI MSI..."
        Invoke-WebRequest -Uri $downloadUri -OutFile .\AzureCLI.msi
    } else {
        Write-Host "Azure CLI MSI already exists."
    }

    # Install Azure CLI
    Write-Host "Installing Azure CLI..."
    Start-Process msiexec.exe -Wait -ArgumentList "/I AzureCLI.msi" -RedirectStandardError $logFilePath
    Write-Host "Azure CLI installation completed successfully."
        
    # Add Azure CLI to the PATH environment variable
    $path = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($path -notlike "*$installPath*") {
        Write-Host "Adding Azure CLI to PATH..."
        $newPath = "$installPath;$path"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
        Write-Host "Azure CLI added to PATH successfully."
    } else {
        Write-Host "Azure CLI is already in the PATH."
     }

    # Delete Azure CLI MSI file
    Remove-Item .\AzureCLI.msi -Force
} else {
    Write-Host "Azure CLI is already installed."
}
