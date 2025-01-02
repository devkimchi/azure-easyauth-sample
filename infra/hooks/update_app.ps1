# Runs the update_app script
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Updates EasyAuth settings for Azure Container App and Azure App Service
# 4. Update the application on Microsoft Entra ID

# $REPOSITORY_ROOT = git rev-parse --show-toplevel
$REPOSITORY_ROOT = "$(Split-Path $MyInvocation.MyCommand.Path)/../.."

# Load the azd environment variables
& "$REPOSITORY_ROOT/infra/hooks/load_azd_env.ps1"

if ([string]::IsNullOrEmpty($env:GITHUB_WORKSPACE)) {
    # The GITHUB_WORKSPACE is not set, meaning this is not running in a GitHub Action
    & "$REPOSITORY_ROOT/infra/hooks/login.ps1"
}

$AZURE_ENV_NAME = $env:AZURE_ENV_NAME

# Run only if GITHUB_WORKSPACE is NOT set - this is NOT running in a GitHub Action workflow
if ([string]::IsNullOrEmpty($env:GITHUB_WORKSPACE)) {
    Write-Host "Updating the EasyAuth settings..."

    $CLIENT_ID = $env:AZURE_PRINCIPAL_ID
    $TENANT_ID = az account show --query "tenantId" -o tsv

    $RESOURCE_GROUP = "rg-$env:AZURE_ENV_NAME"

    $WEBAPP_NAME = $env:AZURE_RESOURCE_EASYAUTH_WEBAPP_NAME
    $CONTAINERAPP_NAME = $env:AZURE_RESOURCE_EASYAUTH_CONTAINERAPP_NAME
    $STATICAPP_NAME = $env:AZURE_RESOURCE_EASYAUTH_STATICAPP_NAME
    $STORAGE_NAME = $env:AZURE_STORAGE_ACCOUNT_NAME

    $WEBAPP_URL = $env:AZURE_RESOURCE_EASYAUTH_WEBAPP_URL
    $CONTAINERAPP_URL = $env:AZURE_RESOURCE_EASYAUTH_CONTAINERAPP_URL
    $STATICAPP_URL = $env:AZURE_RESOURCE_EASYAUTH_STATICAPP_URL
    $STORAGE_URL = $env:AZURE_STORAGE_ACCOUNT_ENDPOINT

    # Get a service principal
    $appId = $CLIENT_ID
    $objectId = az ad app show --id $appId --query "id" -o tsv

    # Add client secret to the app
    $clientSecret = az ad app credential reset --id $appId --display-name "default" --query "password" -o tsv

    # Generate a SAS URL for the token store
    $accountKey = az storage account keys list -g $RESOURCE_GROUP -n $STORAGE_NAME --query "[0].value" -o tsv
    $expiry = $(Get-Date).AddMonths(6).ToString("yyyy-MM-dd")
    $sasToken = az storage account generate-sas --account-name $STORAGE_NAME --account-key $accountKey --expiry $expiry --https-only --permissions acuw --resource-types co --services bfqt -o tsv
    $sasUrl = "$STORAGE_URL`?$sasToken"
    
    # Update EasyAuth settings for Azure Container App
    Write-Host "...Updating Azure Container Apps..."

    $__ = az containerapp secret set -g $RESOURCE_GROUP -n $CONTAINERAPP_NAME --secrets microsoft-provider-authentication-secret=$clientSecret
    # To pass SAS URL: https://learn.microsoft.com/cli/azure/use-azure-cli-successfully-powershell#pass-parameters-containing-the-ampersand-symbol
    $__ = az containerapp secret set -g $RESOURCE_GROUP -n $CONTAINERAPP_NAME --secrets token-store-sas-url="""$sasUrl"""
    $__ = az containerapp update -g $RESOURCE_GROUP -n $CONTAINERAPP_NAME --set-env-vars MICROSOFT_PROVIDER_AUTHENTICATION_SECRET=$clientSecret
    
    $__ = az containerapp auth microsoft update -g $RESOURCE_GROUP -n $CONTAINERAPP_NAME --client-id $CLIENT_ID --client-secret $clientSecret --tenant-id $TENANT_ID -y
    $__ = az containerapp auth update -g $RESOURCE_GROUP -n $CONTAINERAPP_NAME --action AllowAnonymous --redirect-provider AzureActiveDirectory --require-https true --token-store true --sas-url-secret-name token-store-sas-url -y

    $__ = az containerapp update -g $RESOURCE_GROUP -n $CONTAINERAPP_NAME --set-env-vars MsGraph__TenantId="$TENANT_ID" `
                                                                                         MsGraph__ClientId="$CLIENT_ID" `
                                                                                         MsGraph__ClientSecret="$clientSecret"

    # Update EasyAuth settings for Azure App Service
    Write-Host "...Updating Azure App Service..."

    $__ = az webapp auth microsoft update -g $RESOURCE_GROUP -n $WEBAPP_NAME --client-id $CLIENT_ID --client-secret $clientSecret --tenant-id $TENANT_ID -y

    $__ = az webapp config appsettings set -g $RESOURCE_GROUP -n $WEBAPP_NAME --settings MsGraph__TenantId="$TENANT_ID" `
                                                                                         MsGraph__ClientId="$CLIENT_ID" `
                                                                                         MsGraph__ClientSecret="$clientSecret"

    # Update EasyAuth settings for Azure Static Web Apps
    Write-Host "...Updating Azure Static Web Apps..."

    $__ = az staticwebapp appsettings set -g $RESOURCE_GROUP -n $STATICAPP_NAME --setting-names MsGraph__TenantId="$TENANT_ID" `
                                                                                                MsGraph__ClientId="$CLIENT_ID" `
                                                                                                MsGraph__ClientSecret="$clientSecret"

    Write-Host "...Done"

    Write-Host "Updating the application on Microsoft Entra ID..."

    # Add identifier URIs to the app
    Write-Host "...Adding Identifier URIs..."

    $__ = az ad app update --id $appId --identifier-uris "api://$appId"

    # Add API scopes to the app
    Write-Host "...Adding API scopes..."

    $app = az ad app show --id $appId | ConvertFrom-Json
    if ($app.api.oauth2PermissionScopes.Count -gt 0) {
        # Disable all existing scopes
        $scope = $app.api.oauth2PermissionScopes[0]
        $scope.isEnabled = $false
        $api = @{
            requestedAccessTokenVersion = 2;
            oauth2PermissionScopes = @( $scope );
        }
        $__ = az ad app update --id $appId --set api=$($api | ConvertTo-Json -Depth 100 -Compress | ConvertTo-Json)

        # Remove all existing scopes
        $api = @{
            requestedAccessTokenVersion = 2;
            oauth2PermissionScopes = @();
        }
        $__ = az ad app update --id $appId --set api=$($api | ConvertTo-Json -Depth 100 -Compress | ConvertTo-Json)
    }

    $api = @{
        requestedAccessTokenVersion = 2;
        oauth2PermissionScopes = @(
            @{
                id = $(New-Guid).Guid;
                type = "User";
                value = "user_impersonation";
                adminConsentDisplayName = "Access as the signed-in user";
                adminConsentDescription = "Access as the signed-in user";
                isEnabled = $true;
            }
        )
    }
    $__ = az ad app update --id $appId --set api=$($api | ConvertTo-Json -Depth 100 -Compress | ConvertTo-Json)

    # Add web settings to the app
    Write-Host "...Adding web settings..."

    $web = @{
        redirectUris = @(
            "$WEBAPP_URL/.auth/login/aad/callback",
            "$CONTAINERAPP_URL/.auth/login/aad/callback"
        )
        implicitGrantSettings = @{
            enableIdTokenIssuance = $true;
        }
    }
    $__ = az ad app update --id $appId --set web=$($web | ConvertTo-Json -Depth 100 -Compress | ConvertTo-Json)

    # Add API permissions to the app
    Write-Host "...Adding API permissions..."

    $resourceAccess = @(
        @{ id = "06da0dbc-49e2-44d2-8312-53f166ab848a"; type = "Scope"; },
        @{ id = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0"; type = "Scope"; },
        @{ id = "5f8c59db-677d-491f-a6b8-5f174b11ec1d"; type = "Scope"; },
        @{ id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"; type = "Scope"; },
        @{ id = "37f7f235-527c-4136-accd-4a02d197296e"; type = "Scope"; },
        @{ id = "14dad69e-099b-42c9-810b-d002981feec1"; type = "Scope"; },
        @{ id = "a154be20-db9c-4678-8ab7-66f6cc099a59"; type = "Scope"; }
    )
    $requiredResourceAccess = @(
        @{
            resourceAppId = "00000003-0000-0000-c000-000000000000";
            resourceAccess = $resourceAccess;
        }
    )
    $payload = @{ requiredResourceAccess = $requiredResourceAccess; } | ConvertTo-Json -Depth 100 -Compress | ConvertTo-Json
    az rest -m PATCH --uri "https://graph.microsoft.com/v1.0/applications/$objectId" --headers Content-Type=application/json --body $payload

    # Add optional claims to the app
    Write-Host "...Adding optinal claims..."

    $groupClaim = @{
        additionalProperties = @( "emit_as_roles" );
        essential = $false;
        name = "groups";
        source = $null;
    }
    $optionalClaims = @{
        accessToken = @( $groupClaim );
        idToken = @( $groupClaim );
        saml2Token = @( $groupClaim );
    }
    $__ = az ad app update --id $appId --set optionalClaims=$($optionalClaims | ConvertTo-Json -Depth 100 -Compress | ConvertTo-Json)
    $__ = az ad app update --id $appId --set groupMembershipClaims="SecurityGroup"

    Write-Host "...Done"
} else {
    Write-Host "Skipping to update the application on Microsoft Entra ID..."
}
