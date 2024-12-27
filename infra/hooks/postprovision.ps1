# Runs the post-provision script after the environment is provisioned
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Updates the application on Microsoft Entra ID

Write-Host "Running post-provision script..."

# $REPOSITORY_ROOT = git rev-parse --show-toplevel
$REPOSITORY_ROOT = "$(Split-Path $MyInvocation.MyCommand.Path)/../.."

# Update the Entra ID application
& "$REPOSITORY_ROOT/infra/hooks/update_app.ps1"
