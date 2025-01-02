#!/bin/bash

# Runs the deploy_swa script
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Build SWA app
# 4. Deploy SWA app

set -e

# REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
REPOSITORY_ROOT="$(dirname "$(realpath "$0")")/../.."

# Load the azd environment variables
source "$REPOSITORY_ROOT/infra/hooks/load_azd_env.sh"

if [ -z "$GITHUB_WORKSPACE" ]; then
    # The GITHUB_WORKSPACE is not set, meaning this is not running in a GitHub Action
    source "$REPOSITORY_ROOT/infra/hooks/login.sh"
fi

# Run only if GITHUB_WORKSPACE is NOT set - this is NOT running in a GitHub Action workflow
if [ -z "$GITHUB_WORKSPACE" ]; then
    echo "Deploying to Azure Static Web Apps..."

    RESOURCE_GROUP="rg-$AZURE_ENV_NAME"
    STATICAPP_NAME=$AZURE_RESOURCE_EASYAUTH_STATICAPP_NAME

    # Build SWA app
    swa build

    # Get deployment token
    deploymentToken=$(az staticwebapp secrets list \
        --resource-group "$RESOURCE_GROUP" \
        --name "$STATICAPP_NAME" \
        --query "properties.apiKey" -o tsv)

    # Deploy SWA app
    swa deploy \
        --api-location src/EasyAuth.FunctionApp/bin/Release/net9.0 \
        --env Production \
        -d "$deploymentToken"

    echo "...Done"
else
    echo "Skipping to deploy the application Azure Static Web Apps..."
fi
