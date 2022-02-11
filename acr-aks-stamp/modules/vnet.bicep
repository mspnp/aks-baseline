param aksControlPlanePrincipalId string
param vnetName string
param aksSubnetName string
param aksIngressSubnetName string

var networkContributorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' existing = {
  name: vnetName
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  name: aksSubnetName
  parent: vnet
}

resource aksIngressSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  name: aksIngressSubnetName
  parent: vnet
}

// Allows cluster identity to join the nodepool vmss resources to this subnet.
resource aksNodeSubnetContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${aksControlPlanePrincipalId}-${aksSubnet.id}-subnet-roleassignment')
  scope: aksSubnet
  properties: {
    principalId: aksControlPlanePrincipalId
    roleDefinitionId: networkContributorRole
    principalType: 'ServicePrincipal'
  }
}

// Allows cluster identity to join load balancers (ingress resources) to this subnet.
resource aksIngressSubnetContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${aksControlPlanePrincipalId}-${aksIngressSubnet.id}-subnet-roleassignment')
  scope: aksIngressSubnet
  properties: {
    principalId: aksControlPlanePrincipalId
    roleDefinitionId: networkContributorRole
    principalType: 'ServicePrincipal'
  }
}
