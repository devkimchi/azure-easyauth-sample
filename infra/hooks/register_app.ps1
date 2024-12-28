# Runs the register_app script
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Registers the application on Microsoft Entra ID

# $REPOSITORY_ROOT = git rev-parse --show-toplevel
$REPOSITORY_ROOT = "$(Split-Path $MyInvocation.MyCommand.Path)/../.."

# Load the azd environment variables
& "$REPOSITORY_ROOT/infra/hooks/load_azd_env.ps1" -ShowMessage

if ([string]::IsNullOrEmpty($env:GITHUB_WORKSPACE)) {
    # The GITHUB_WORKSPACE is not set, meaning this is not running in a GitHub Action
    & "$REPOSITORY_ROOT/infra/hooks/login.ps1"
}

$AZURE_ENV_NAME = $env:AZURE_ENV_NAME

# Run only if GITHUB_WORKSPACE is NOT set - this is NOT running in a GitHub Action workflow
if ([string]::IsNullOrEmpty($env:GITHUB_WORKSPACE)) {
    Write-Host "Registering the application Microsoft Entra ID..."

    # Create a service principal
    $appId = $env:AZURE_PRINCIPAL_ID
    if ([string]::IsNullOrEmpty($appId)) {
        $appId = az ad app list --display-name "spn-$AZURE_ENV_NAME" --query "[].appId" -o tsv
        if ([string]::IsNullOrEmpty($appId)) {
            $appId = az ad app create --display-name spn-$AZURE_ENV_NAME --query "appId" -o tsv
            $spnId = az ad sp create --id $appId --query "id" -o tsv
        }
    }

    $spnId = az ad sp list --display-name "spn-$AZURE_ENV_NAME" --query "[].id" -o tsv
    if ([string]::IsNullOrEmpty($spnId)) {
        $spnId = az ad sp create --id $appId --query "id" -o tsv
    }

    # Set the environment variables
    azd env set AZURE_PRINCIPAL_ID $appId

    Write-Host "...Done"
} else {
    Write-Host "Skipping to register the application on Microsoft Entra ID..."
}
