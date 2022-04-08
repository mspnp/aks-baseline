param miClusterControlPlanePrincipalId string
param clusterControlPlaneIdentityName string
param vnetName string

var networkContributorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'

resource snetClusterNodes 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${vnetName}/snet-clusternodes'
}

resource snetClusterIngress 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${vnetName}/snet-clusteringressservices'
}

resource snetClusterNodesMiClusterControlPlaneNetworkContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: snetClusterNodes
  name: guid(snetClusterNodes.id, networkContributorRole, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: networkContributorRole
    description: 'Allows cluster identity to join the nodepool vmss resources to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource snetClusterIngressServicesMiClusterControlPlaneSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: snetClusterIngress
  name: guid(snetClusterIngress.id, networkContributorRole, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: networkContributorRole
    description: 'Allows cluster identity to join load balancers (ingress resources) to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}
