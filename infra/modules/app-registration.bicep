extension microsoftGraphV1

param webAppIdentityId string
param containerAppIdentityId string

param clientAppName string
param clientAppDisplayName string = clientAppName

param issuer string

param webAppEndpoint string
param containerAppEndpoint string

var identifierId = guid(clientAppName)

var groupClaim = {
  name: 'groups'
  essential: false
  additionalProperties: [
    'emit_as_roles'
  ]
  source: null
}

resource clientApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: clientAppName
  displayName: clientAppDisplayName
  identifierUris: [
    'api://${identifierId}'
  ]
  web: {
    redirectUris: [
      '${webAppEndpoint}/.auth/login/aad/callback'
      '${containerAppEndpoint}/.auth/login/aad/callback'
    ]
    implicitGrantSettings: {
      enableIdTokenIssuance: true
    }
  }
  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: identifierId
        type: 'User'
        isEnabled: true
        value: 'user_impersonation'
        adminConsentDisplayName: 'Access as the signed-in user'
        adminConsentDescription: 'Access as the signed-in user'
      }
    ]
  }
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000'
      resourceAccess: [
        // email
        { id: '64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0', type: 'Scope' }
        // offline_access
        { id: '7427e0e9-2fba-42fe-b0c0-848c9e6a8182', type: 'Scope' }
        // openid
        { id: '37f7f235-527c-4136-accd-4a02d197296e', type: 'Scope' }
        // profile
        { id: '14dad69e-099b-42c9-810b-d002981feec1', type: 'Scope' }
        // User.Read.All
        { id: 'a154be20-db9c-4678-8ab7-66f6cc099a59', type: 'Scope' }
        // Group.Read.All
        { id: '5f8c59db-677d-491f-a6b8-5f174b11ec1d', type: 'Scope' }
        // Directory.Read.All
        { id: '06da0dbc-49e2-44d2-8312-53f166ab848a', type: 'Scope' }
      ]
    }
  ]
  optionalClaims: {
    accessToken: [
      groupClaim
    ]
    saml2Token: [
      groupClaim
    ]
    idToken: [
      groupClaim
    ]
  }
  groupMembershipClaims: 'SecurityGroup'

  resource clientAppFicWebApp 'federatedIdentityCredentials@v1.0' = {
    name: '${clientApp.uniqueName}/fic-webapp'
    issuer: issuer
    subject: webAppIdentityId
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }

  resource clientAppFicContainerApp 'federatedIdentityCredentials@v1.0' = {
    name: '${clientApp.uniqueName}/fic-containerapp'
    issuer: issuer
    subject: containerAppIdentityId
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource clientSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: clientApp.appId
}

output clientAppId string = clientApp.appId
output clientSpId string = clientSp.id
