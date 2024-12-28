# Runs the pre-provision script before the environment is provisioned
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action

Write-Host "Running pre-provision script..."

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
    Write-Host "Registering the application in Azure..."

    # Create a service principal
    $appId = $env:AZURE_CLIENT_ID
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

    $objectId = az ad app show --id $appId --query "id" -o tsv

    # Add client secret to the app
    $clientSecret = az ad app credential reset --id $appId --display-name "default" --append

    # Add identifier URIs to the app
    $identifierUris = @( "api://$appId" )

    # Add API scopes to the app
    $api = @{
        acceptMappedClaims = $null;
        knownClientApplications = @();
        requestedAccessTokenVersion = $null;
        oauth2PermissionScopes = @(
            @{
                type = "User";
                value = "user_impersonation";
                adminConsentDisplayName = "Access EasyAuth apps";
                adminConsentDescription = "Allows users to access apps using EasyAuth";
                isEnabled = $true;
            }
        )
    }

    $payload = @{ $identifierUris = $identifierUris; api = $api } | ConvertTo-Json -Depth 100 -Compress | ConvertTo-Json

    az rest -m PATCH `
        --uri "https://graph.microsoft.com/v1.0/applications/$objectId" `
        --headers Content-Type=application/json `
        --body $payload

    # Set the environment variables
    azd env set AZURE_PRINCIPAL_ID $appId
    azd env set AZURE_PRINCIPAL_SECRET $clientSecret
} else {
    Write-Host "Skipping to register the application in Azure..."
}
