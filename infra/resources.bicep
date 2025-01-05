@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

param easyauthContainerappExists bool
@secure()
param easyauthContainerappDefinition object

@allowed([
  'centralus'
  'eastasia'
  'eastus2'
  'westeurope'
  'westus2'
])
param sttappLocation string

@description('Id of the user or app to assign application roles')
param principalId string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}

// Storage account
module storageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: 'storageAccount'
  params: {
    name: '${abbrs.storageStorageAccounts}${resourceToken}'
    kind: 'StorageV2'
    location: location
    tags: tags
    skuName: 'Standard_LRS'
    allowBlobPublicAccess: false
    blobServices: {
      containers: [
        {
          name: 'token-store'
          publicAccess: 'None'
        }
      ]
    }
  }
}

// Container registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.6.0' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    acrAdminUserEnabled: true
    tags: tags
    exportPolicyStatus: 'enabled'
    publicNetworkAccess: 'Enabled'
    roleAssignments:[
      {
        principalId: easyauthContainerappIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.8.1' = {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}

module easyauthContainerappIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'easyauthContainerappidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}easyauthContainerapp-${resourceToken}'
    location: location
  }
}

module easyauthContainerappFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'easyauthContainerapp-fetch-image'
  params: {
    exists: easyauthContainerappExists
    name: 'easyauth-containerapp'
  }
}

var easyauthContainerappAppSettingsArray = filter(array(easyauthContainerappDefinition.settings), i => i.name != '')
var easyauthContainerappSecrets = map(filter(easyauthContainerappAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var easyauthContainerappEnv = map(filter(easyauthContainerappAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module easyauthContainerapp 'br/public:avm/res/app/container-app:0.11.0' = {
  name: 'easyauthContainerapp'
  params: {
    name: 'easyauth-containerapp'
    ingressTargetPort: 8080
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList: union([
      ],
      map(easyauthContainerappSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: easyauthContainerappFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: easyauthContainerappIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '8080'
          }
        ],
        easyauthContainerappEnv,
        map(easyauthContainerappSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [easyauthContainerappIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: easyauthContainerappIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'easyauth-containerapp' })
  }
}

// Create App Service Plan
module easyauthWebappServerfarm 'br/public:avm/res/web/serverfarm:0.4.0' = {
  name: 'easyauthWebapp-serverfarm'
  params: {
    name: '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    reserved: true
    skuName: 'B1'
    skuCapacity: 1
  }
}

// Create Web App
module easyauthWebapp 'br/public:avm/res/web/site:0.12.1' = {
  name: 'easyauthWebapp'
  params: {
    name: '${abbrs.webSitesAppService}${resourceToken}'
    kind: 'app,linux'
    serverFarmResourceId: easyauthWebappServerfarm.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'easyauth-webapp' })
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'USE_AUTH_DETAILS'
          value: 'false'
        }
      ]
      ftpsState: 'FtpsOnly'
      linuxFxVersion: 'DOTNETCORE|9.0'
      alwaysOn: true
      minTlsVersion: '1.2'
    }
    authSettingV2Configuration: {
      globalValidation: {
        unauthenticatedClientAction: 'AllowAnonymous'
        redirectToProvider: 'AzureActiveDirectory'
      }
      httpSettings: {
        requireHttps: true
      }
      login: {
        tokenStore: {
          enabled: true
        }
      }
      platform: {
        enabled: true
      }
    }
    basicPublishingCredentialsPolicies: [
      {
        name: 'scm'
        allow: false
      }
      {
        name: 'ftp'
        allow: false
      }
    ]
  }
}

// Create a Static Web App
module easyauthSwaapp 'br/public:avm/res/web/static-site:0.6.1' = {
  name: 'easyauthSwaapp'
  params: {
    name: '${abbrs.webStaticSites}${resourceToken}'
    location: sttappLocation
    tags: union(tags, { 'azd-service-name': 'easyauth-swaapp' })
  }
}

// Create a keyvault to store secrets
module keyVault 'br/public:avm/res/key-vault/vault:0.11.1' = {
  name: 'keyvault'
  params: {
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    enableRbacAuthorization: false
    accessPolicies: [
      {
        objectId: principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: easyauthContainerappIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
    ]
    secrets: [
    ]
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.uri
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name

output AZURE_STORAGE_ACCOUNT_NAME string = storageAccount.outputs.name
output AZURE_STORAGE_ACCOUNT_ENDPOINT string = storageAccount.outputs.primaryBlobEndpoint

output AZURE_RESOURCE_EASYAUTH_WEBAPP_ID string = easyauthWebapp.outputs.resourceId
output AZURE_RESOURCE_EASYAUTH_CONTAINERAPP_ID string = easyauthContainerapp.outputs.resourceId
output AZURE_RESOURCE_EASYAUTH_STATICAPP_ID string = easyauthSwaapp.outputs.resourceId

output AZURE_RESOURCE_EASYAUTH_WEBAPP_NAME string = easyauthWebapp.outputs.name
output AZURE_RESOURCE_EASYAUTH_CONTAINERAPP_NAME string = easyauthContainerapp.outputs.name
output AZURE_RESOURCE_EASYAUTH_STATICAPP_NAME string = easyauthSwaapp.outputs.name

output AZURE_RESOURCE_EASYAUTH_WEBAPP_URL string = 'https://${easyauthWebapp.outputs.defaultHostname}'
output AZURE_RESOURCE_EASYAUTH_CONTAINERAPP_URL string = 'https://${easyauthContainerapp.outputs.fqdn}'
output AZURE_RESOURCE_EASYAUTH_STATICAPP_URL string = 'https://${easyauthSwaapp.outputs.defaultHostname}'
