# Runs the pre-up script before the environment is provisioned
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Registers the application on Microsoft Entra ID

Write-Host "Running pre-up script..."

# $REPOSITORY_ROOT = git rev-parse --show-toplevel
$REPOSITORY_ROOT = "$(Split-Path $MyInvocation.MyCommand.Path)/../.."

# Register the Entra ID application in Azure
& "$REPOSITORY_ROOT/infra/hooks/register_app.ps1"
