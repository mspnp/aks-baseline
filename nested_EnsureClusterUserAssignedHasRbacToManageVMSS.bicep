targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The AKS Kubelet identity Object Id to be given with Virtual Machine Contributor Role to work with Managed Identities and aad-pod-identity')
@minLength(36)
@maxLength(36)
param kubeletidentityObjectId string

/*** EXISTING SUBSCRIPTION RESOURCES ***/

resource virtualMachineContributorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
  scope: subscription()
}

/*** RESOURCES ***/

// It is required to grant the AKS cluster with Virtual Machine Contributor role permissions over the cluster infrastructure resource group to work with Managed Identities.
resource id 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, virtualMachineContributorRole.id)
  properties: {
    roleDefinitionId: virtualMachineContributorRole.id
    principalId: kubeletidentityObjectId
    principalType: 'ServicePrincipal'
  }
}
