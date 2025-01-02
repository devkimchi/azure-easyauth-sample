#!/bin/bash

# Runs the update_app script
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Updates EasyAuth settings for Azure Container App and Azure App Service
# 4. Update the application on Microsoft Entra ID

set -e

# REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
REPOSITORY_ROOT="$(dirname $(realpath $0))/../.."

# Load the azd environment variables
source "$REPOSITORY_ROOT/infra/hooks/load_azd_env.sh"

if [[ -z "$GITHUB_WORKSPACE" ]]; then
    # The GITHUB_WORKSPACE is not set, meaning this is not running in a GitHub Action
    source "$REPOSITORY_ROOT/infra/hooks/login.sh"
fi

# Run only if GITHUB_WORKSPACE is NOT set
if [[ -z "$GITHUB_WORKSPACE" ]]; then
    echo "Updating the EasyAuth settings..."

    CLIENT_ID="$AZURE_PRINCIPAL_ID"
    TENANT_ID=$(az account show --query "tenantId" -o tsv)

    RESOURCE_GROUP="rg-$AZURE_ENV_NAME"

    WEBAPP_NAME="$AZURE_RESOURCE_EASYAUTH_WEBAPP_NAME"
    CONTAINERAPP_NAME="$AZURE_RESOURCE_EASYAUTH_CONTAINERAPP_NAME"
    STATICAPP_NAME="$AZURE_RESOURCE_EASYAUTH_STATICAPP_NAME"
    STORAGE_NAME="$AZURE_STORAGE_ACCOUNT_NAME"

    WEBAPP_URL="$AZURE_RESOURCE_EASYAUTH_WEBAPP_URL"
    CONTAINERAPP_URL="$AZURE_RESOURCE_EASYAUTH_CONTAINERAPP_URL"
    STATICAPP_URL="$AZURE_RESOURCE_EASYAUTH_STATICAPP_URL"
    STORAGE_URL="$AZURE_STORAGE_ACCOUNT_ENDPOINT"

    # Get a service principal
    appId="$CLIENT_ID"
    objectId=$(az ad app show --id "$appId" --query "id" -o tsv)

    # Add client secret to the app
    clientSecret=$(az ad app credential reset --id "$appId" --display-name "default" --query "password" -o tsv)

    # Generate a SAS URL for the token store
    accountKey=$(az storage account keys list -g "$RESOURCE_GROUP" -n "$STORAGE_NAME" --query "[0].value" -o tsv)
    expiry=$(date -d "+6 months" +%Y-%m-%d)
    sasToken=$(az storage account generate-sas --account-name "$STORAGE_NAME" --account-key "$accountKey" --expiry "$expiry" --https-only --permissions acuw --resource-types co --services bfqt -o tsv)
    sasUrl="$STORAGE_URL?$sasToken"

    # Update EasyAuth settings for Azure Container App
    echo "...Updating Azure Container Apps..."

    __=$(az containerapp secret set -g "$RESOURCE_GROUP" -n "$CONTAINERAPP_NAME" --secrets microsoft-provider-authentication-secret="$clientSecret")
    __=$(az containerapp secret set -g "$RESOURCE_GROUP" -n "$CONTAINERAPP_NAME" --secrets token-store-sas-url="$sasUrl")
    __=$(az containerapp update -g "$RESOURCE_GROUP" -n "$CONTAINERAPP_NAME" --set-env-vars MICROSOFT_PROVIDER_AUTHENTICATION_SECRET="$clientSecret")

    __=$(az containerapp auth microsoft update -g "$RESOURCE_GROUP" -n "$CONTAINERAPP_NAME" --client-id "$CLIENT_ID" --client-secret "$clientSecret" --tenant-id "$TENANT_ID" -y)
    __=$(az containerapp auth update -g "$RESOURCE_GROUP" -n "$CONTAINERAPP_NAME" --action AllowAnonymous --redirect-provider AzureActiveDirectory --require-https true --token-store true --sas-url-secret-name token-store-sas-url -y)

    __=$(az containerapp update -g "$RESOURCE_GROUP" -n "$CONTAINERAPP_NAME" --set-env-vars MsGraph__TenantId="$TENANT_ID" \
                                                                                            MsGraph__ClientId="$CLIENT_ID" \
                                                                                            MsGraph__ClientSecret="$clientSecret")

    # Update EasyAuth settings for Azure App Service
    echo "...Updating Azure App Service..."

    __=$(az webapp auth microsoft update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --client-id "$CLIENT_ID" --client-secret "$clientSecret" --tenant-id "$TENANT_ID" -y)
    __=$(az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings MsGraph__TenantId="$TENANT_ID" \
                                                                                            MsGraph__ClientId="$CLIENT_ID" \
                                                                                            MsGraph__ClientSecret="$clientSecret")

    # Update EasyAuth settings for Azure Static Web Apps
    echo "...Updating Azure Static Web Apps..."

    __=$(az staticwebapp appsettings set -g "$RESOURCE_GROUP" -n "$STATICAPP_NAME" --setting-names MsGraph__TenantId="$TENANT_ID" \
                                                                                                   MsGraph__ClientId="$CLIENT_ID" \
                                                                                                   MsGraph__ClientSecret="$clientSecret")

    echo "...Done"

    echo "Updating the application on Microsoft Entra ID..."

    # Add identifier URIs to the app
    echo "...Adding Identifier URIs..."

    __=$(az ad app update --id "$appId" --identifier-uris "api://$appId")

    # Add API scopes to the app
    echo "...Adding API scopes..."

    app=$(az ad app show --id "$appId" -o json)
    scope=$(echo "$app" | jq '.api.oauth2PermissionScopes[0]')
    if [[ "$scope" != "null" ]]; then
        scope=$(echo "$scope" | jq '.isEnabled = false')
        api=$(jq -n --argjson scope "$scope" '{requestedAccessTokenVersion: 2, oauth2PermissionScopes: [$scope]}')
        __=$(az ad app update --id "$appId" --set api="$api")

        api=$(jq -n '{requestedAccessTokenVersion: 2, oauth2PermissionScopes: []}')
        __=$(az ad app update --id "$appId" --set api="$api")
    fi

    api=$(jq -n \
        '{
          requestedAccessTokenVersion: 2,
          oauth2PermissionScopes: [
            { id: "'$(uuidgen)'",
              type: "User",
              value: "user_impersonation",
              adminConsentDisplayName: "Access as the signed-in user",
              adminConsentDescription: "Access as the signed-in user",
              isEnabled: true
            }
          ]
        }')
    __=$(az ad app update --id "$appId" --set api="$api")

    # Add web settings to the app
    echo "...Adding web settings..."

    web=$(jq -n --arg webAppUrl "$WEBAPP_URL" --arg containerAppUrl "$CONTAINERAPP_URL" \
        '{
          redirectUris: [
            $webAppUrl + "/.auth/login/aad/callback",
            $containerAppUrl + "/.auth/login/aad/callback"
          ],
          implicitGrantSettings: {
            enableIdTokenIssuance: true
          }
        }')
    __=$(az ad app update --id "$appId" --set web="$web")

    # Add API permissions to the app
    echo "...Adding API permissions..."

    resourceAccess=$(jq -n '[
        {id: "06da0dbc-49e2-44d2-8312-53f166ab848a", type: "Scope"},
        {id: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", type: "Scope"},
        {id: "5f8c59db-677d-491f-a6b8-5f174b11ec1d", type: "Scope"},
        {id: "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", type: "Scope"},
        {id: "37f7f235-527c-4136-accd-4a02d197296e", type: "Scope"},
        {id: "14dad69e-099b-42c9-810b-d002981feec1", type: "Scope"},
        {id: "a154be20-db9c-4678-8ab7-66f6cc099a59", type: "Scope"}
    ]')
    requiredResourceAccess=$(jq -n --argjson resourceAccess "$resourceAccess" \
        '[
          { resourceAppId: "00000003-0000-0000-c000-000000000000",
            resourceAccess: $resourceAccess
          }
        ]')
    az rest -m PATCH --uri "https://graph.microsoft.com/v1.0/applications/$objectId" --headers Content-Type=application/json --body "{ \"requiredResourceAccess\": $requiredResourceAccess }"

    # Add optional claims to the app
    echo "...Adding optional claims..."

    groupClaim=$(jq -n \
        '{
          additionalProperties: [
            "emit_as_roles"
          ],
          essential: false,
          name: "groups"
        }')
    optionalClaims=$(jq -n --argjson groupClaim "$groupClaim" \
        '{
          accessToken: [
            $groupClaim
          ],
          idToken: [
            $groupClaim
          ],
          saml2Token: [
            $groupClaim
          ]
        }')
    __=$(az ad app update --id "$appId" --set optionalClaims="$optionalClaims")
    __=$(az ad app update --id "$appId" --set groupMembershipClaims="SecurityGroup")

    echo "...Done"
else
    echo "Skipping to update the application on Microsoft Entra ID..."
fi
