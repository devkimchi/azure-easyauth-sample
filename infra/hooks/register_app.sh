#!/bin/bash

# Runs the register_app script
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Registers the application on Microsoft Entra ID

set -e

# REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
REPOSITORY_ROOT="$(dirname "$(realpath "$0")")/../.."

# Load the azd environment variables
source "$REPOSITORY_ROOT/infra/hooks/load_azd_env.sh" --show-message

if [ -z "$GITHUB_WORKSPACE" ]; then
    # The GITHUB_WORKSPACE is not set, meaning this is not running in a GitHub Action
    source "$REPOSITORY_ROOT/infra/hooks/login.sh"
fi

# Run only if GITHUB_WORKSPACE is NOT set - this is NOT running in a GitHub Action workflow
if [ -z "$GITHUB_WORKSPACE" ]; then
    echo "Registering the application Microsoft Entra ID..."

    # Create a service principal
    appId=$AZURE_PRINCIPAL_ID
    if [ -z "$appId" ]; then
        appId=$(az ad app list --display-name "spn-$AZURE_ENV_NAME" --query "[].appId" -o tsv)
        if [ -z "$appId" ]; then
            appId=$(az ad app create --display-name "spn-$AZURE_ENV_NAME" --query "appId" -o tsv)
            spnId=$(az ad sp create --id "$appId" --query "id" -o tsv)
        fi
    fi

    spnId=$(az ad sp list --display-name "spn-$AZURE_ENV_NAME" --query "[].id" -o tsv)
    if [ -z "$spnId" ]; then
        spnId=$(az ad sp create --id "$appId" --query "id" -o tsv)
    fi

    # Set the environment variables
    azd env set AZURE_PRINCIPAL_ID "$appId"

    echo "...Done"
else
    echo "Skipping to register the application on Microsoft Entra ID..."
fi