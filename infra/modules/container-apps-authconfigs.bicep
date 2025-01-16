param containerAppName string
param principalId string
param managedIdentityName string
param storageAccountName string

resource containerapp 'Microsoft.App/containerApps@2024-10-02-preview' existing = {
  name: containerAppName
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource containerappAuthConfig 'Microsoft.App/containerApps/authConfigs@2024-10-02-preview' = {
  name: 'current'
  parent: containerapp
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'AzureActiveDirectory'
    }
    httpSettings: {
      requireHttps: true
    }
    login: {
      tokenStore: {
        enabled: true
        azureBlobStorage: {
          clientId: principalId
        //   managedIdentityResourceId: userAssignedIdentity.id
          blobContainerUri: '${storageAccount.properties.primaryEndpoints.blob}/token-store'
        }
      }
    }
  }
}
