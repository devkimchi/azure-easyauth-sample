#!/bin/bash

# Runs the post-deploy script after the apps are deployed
# It does the following:
# 1. Loads the azd environment variables
# 2. Logs in to the Azure CLI if not running in a GitHub Action
# 3. Deploys the application to Azure Static Web Apps

set -e

echo "Running post-deploy script..."

# REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
REPOSITORY_ROOT="$(dirname "$(realpath "$0")")/../.."

# Deploy SWA app
"$REPOSITORY_ROOT/infra/hooks/deploy_swa.sh"
