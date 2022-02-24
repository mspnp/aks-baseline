param vnetId string
param privateLinkSubnetId string
param keyVaultName string
param location string
param appGWListenerCertificate string
param aksIngressCertificate string
param appGWIdentityPrincipalId string
param aksIngressIdentityPrincipalId string
param logAnalyticsWorkspaceName string

var keyVaultSecretsUserRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
var keyVaultUserRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/21090545-7ca7-4776-b22c-e363652d74d2'
var keyVaultPrivateDnsZoneName = 'privatelink.vaultcore.azure.net'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    accessPolicies: []
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
  }
  resource appGWListenerCertificateSecret 'secrets@2021-06-01-preview' = {
    name: 'gateway-ssl-cert'
    properties: {
      value: appGWListenerCertificate
    }
  }

  resource aksIngressCertificateSecret 'secrets@2021-06-01-preview' = if (!empty(aksIngressCertificate)) {
    name: 'appgw-aks-ingress-tls-cert'
    properties: {
      value: aksIngressCertificate
    }
  }

}

// Grant the Azure Application Gateway managed identity with key vault secret reader role permissions; this allows pulling frontend and backend certificates.
resource appGWKvSecretReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${appGWIdentityPrincipalId}-${keyVault.id}-keyvault-secrets-roleassignment')
  scope: keyVault
  properties: {
    principalId: appGWIdentityPrincipalId
    roleDefinitionId: keyVaultSecretsUserRole
    principalType: 'ServicePrincipal'
  }
}

// Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
resource appGWKvReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${appGWIdentityPrincipalId}-${keyVault.id}-keyvault-roleassignment')
  scope: keyVault
  properties: {
    principalId: appGWIdentityPrincipalId
    roleDefinitionId: keyVaultUserRole
    principalType: 'ServicePrincipal'
  }
}

// Grant the AKS cluster ingress controller pod managed identity with key vault secret reader role permissions; this allows our ingress controller to pull certificates.
resource aksIngressKvSecretReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${aksIngressIdentityPrincipalId}-${keyVault.id}-keyvault-secrets-roleassignment')
  scope: keyVault
  properties: {
    principalId: aksIngressIdentityPrincipalId
    roleDefinitionId: keyVaultSecretsUserRole
    principalType: 'ServicePrincipal'
  }
}

// Grant the AKS cluster ingress controller pod managed identity with key vault reader role permissions; this allows our ingress controller to pull certificates.
resource aksIngressKvReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${aksIngressIdentityPrincipalId}-${keyVault.id}-keyvault-roleassignment')
  scope: keyVault
  properties: {
    principalId: aksIngressIdentityPrincipalId
    roleDefinitionId: keyVaultUserRole
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Microsoft.Insights'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource keyVaultPrivateLink 'Microsoft.Network/privateEndpoints@2020-05-01' = {
  name: 'akv-to-aksvnet'
  location: location
  properties: {
    subnet: {
      id: privateLinkSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'nodepools'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource keyVaultPrivateLinkDnsZone 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-05-01' = {
  parent: keyVaultPrivateLink
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-akv-net'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: keyVaultPrivateDnsZoneName
  location: 'global'
  properties: {}
}

resource keyVaultPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: 'to_aksvnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

resource keyVaultAnalyticsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'KeyVaultAnalytics(${logAnalyticsWorkspaceName})'
  location: location
  properties: {
    workspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  }
  plan: {
    name: 'KeyVaultAnalytics(${logAnalyticsWorkspaceName})'
    product: 'OMSGallery/KeyVaultAnalytics'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

output appGWListenerCertificateSecretId string = keyVault::appGWListenerCertificateSecret.properties.secretUri
output aksIngressCertificateSecretId string = !empty(aksIngressCertificate) ? keyVault::aksIngressCertificateSecret.properties.secretUri : ''
