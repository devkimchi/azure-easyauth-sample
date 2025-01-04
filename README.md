# Azure EasyAuth Sample

This provides sample [Blazor](https://learn.microsoft.com/aspnet/core/blazor/) apps for the EasyAuth feature on Azure App Service, Azure Container Apps and Azure Static Web App.

## Prerequisites

- [.NET 9+ SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- [Visual Studio 2022](https://visualstudio.microsoft.com/vs/) or [Visual Studio Code](https://code.visualstudio.com/) with [C# Dev Kit](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csdevkit)
- [GitHub CLI](https://github.com/cli/cli#installation)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [SWA CLI](https://learn.microsoft.com/azure/static-web-apps/static-web-apps-cli-install)

## Getting Started

1. Clone this repository.

    ```bash
    gh repo fork devkimchi/azure-easyauth-sample --clone
    ```

1. Change the directory to the repository.

    ```bash
    cd azure-easyauth-sample
    ```

1. Build the sample apps.

    ```bash
    dotnet restore && dotnet build
    ```

1. Login to Azure.

    ```bash
    # Login to Azure with Azure Developer CLI
    azd auth login
    
    # Login to Azure with Azure CLI
    az login
    ```

1. Run the following command to provision and deploy the Azure resources.

    ```bash
    azd up
    ```

   It will ask you to provide the following parameters:

   - New environment name
   - Azure subscription to use
   - Azure location to provision resources
   - `sttappLocation` to provision Azure Static Web App

   It provisions Azure Container Apps, Azure App Service, and Azure Static Web App instances and deploys the sample apps to each of them.

1. Get each app's URL.

    ```bash
    # Web App URL
    azd env get-value AZURE_RESOURCE_EASYAUTH_WEBAPP_URL

    # Container App URL
    azd env get-value AZURE_RESOURCE_EASYAUTH_CONTAINERAPP_URL

    # Static Web App URL
    azd env get-value AZURE_RESOURCE_EASYAUTH_STATICAPP_URL
    ```

1. With the URLs above, navigate each app with your browser. You'll be redirected to login your apps with Entra ID first. Once you logged in, you'll see the logged-in user's information.

## Known Limitations of Azure EasyAuth

Azure EasyAuth is supposed to protect your entire app, not for specific pages. Therefore, if you want to protect certain pages of your app, you have to implement the authentication/authorisation logic by yourself.

## Clean Up

If you want to clean up the resources provisioned by the `azd up` command, run the following command:

```bash
azd down --force --purge
```

## Additional Resources

- [Azure EasyAuth](https://learn.microsoft.com/azure/app-service/scenario-secure-app-authentication-app-service?tabs=workforce-configuration)
- [Azure App Service](https://learn.microsoft.com/azure/app-service/overview)
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/overview)
- [Azure Static Web Apps](https://learn.microsoft.com/azure/static-web-apps/overview)
