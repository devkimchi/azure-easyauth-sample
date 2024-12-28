# Runs the deploy_swa script
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Build SWA app
# 4. Deploy SWA app

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
    Write-Host "Deploying to Azure Static Web Apps..."

    $RESOURCE_GROUP = "rg-$env:AZURE_ENV_NAME"
    $STATICAPP_NAME = $env:AZURE_RESOURCE_EASYAUTH_STATICAPP_NAME

    # Build SWA app
    swa build

    # Get deployment token
    $deploymentToken = az staticwebapp secrets list `
    --resource-group $RESOURCE_GROUP `
    --name $STATICAPP_NAME `
    --query "properties.apiKey" -o tsv

    # Deploy SWA app
    swa deploy `
        --api-location src/EasyAuth.FunctionApp/bin/Release/net9.0 `
        --env Production `
        -d $deploymentToken  

    Write-Host "...Done"
} else {
    Write-Host "Skipping to deploy the application Azure Static Web Apps..."
}
