#!/bin/bash

# Runs the post-provision script before the environment is provisioned
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Updates the application on Microsoft Entra ID

set -e

echo "Running post-provision script..."

# REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
REPOSITORY_ROOT="$(dirname "$(realpath "$0")")/../.."

# Update the Entra ID application in Azure
"$REPOSITORY_ROOT/infra/hooks/update_app.sh"
