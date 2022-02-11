param aksClusterName string
param clusterUserAadGroupObjectId string
param clusterAdminAadGroupObjectId string
param aksIngressIdentityName string
param userNamespaceName string

var managedIdentityOperatorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830'
var clusterAdminRoleId = 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
var clusterReaderRoleId = '7f6c6a51-bcf8-42ba-9220-52d62157d7db'
var serviceClusterUserRoleId = '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'

resource aks 'Microsoft.ContainerService/managedClusters@2021-10-01' existing = {
  name: aksClusterName
}

resource aksUserNamespace 'Microsoft.ContainerService/managedClusters/namespaces@2021-10-01' existing = {
  parent: aks
  name: userNamespaceName
}

resource aksIngressIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: aksIngressIdentityName
}

resource aksClusterAdmins 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: aks
  name: guid('aad-admin-group', aks.id, clusterAdminAadGroupObjectId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${clusterAdminRoleId}'
    description: 'Members of this group are cluster admins of this cluster.'
    principalId: clusterAdminAadGroupObjectId
    principalType: 'Group'
  }
}

resource aksServiceClusterAdmins 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: aks
  name: guid('aad-admin-group-sc', aks.id, clusterAdminAadGroupObjectId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${serviceClusterUserRoleId}'
    description: 'Members of this group are cluster users of this cluster.'
    principalId: clusterAdminAadGroupObjectId
    principalType: 'Group'
  }
}

resource aksUserNamespaceAdmins 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (clusterUserAadGroupObjectId != clusterAdminAadGroupObjectId) {
  scope: aksUserNamespace
  name: guid('aad-${userNamespaceName}-reader-group', aks.id, clusterUserAadGroupObjectId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${clusterReaderRoleId}'
    principalId: clusterUserAadGroupObjectId
    description: 'Members of this group are cluster admins of the a0008 namespace in this cluster.'
    principalType: 'Group'
  }
}

resource aksServiceClusterUsers 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (clusterUserAadGroupObjectId != clusterAdminAadGroupObjectId) {
  scope: aks
  name: guid('aad-${userNamespaceName}-reader-group-sc', aks.id, clusterUserAadGroupObjectId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${serviceClusterUserRoleId}'
    principalId: clusterUserAadGroupObjectId
    description: 'Members of this group are cluster users of this cluster.'
    principalType: 'Group'
  }
}

resource aksManagedIdentityOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: aksIngressIdentity
  name: guid('podmi-ingress-controller/Microsoft.Authorization', resourceGroup().id, aksIngressIdentityName, managedIdentityOperatorRole)
  properties: {
    roleDefinitionId: managedIdentityOperatorRole
    principalId: reference(aks.id, '2020-11-01').identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}
