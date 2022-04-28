targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The AKS Kubelet identity Object Id to be given with Virtual Machine Contributor Role to work with Managed Identities and aad-pod-identity')
@minLength(36)
@maxLength(36)
param kubeletidentityObjectId string

/*** VARIABLES ***/

var virtualMachineContributorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c'

/*** RESOURCES ***/

// It is required to grant the AKS cluster with Virtual Machine Contributor role permissions over the cluster infrastructure resource group to work with Managed Identities and aad-pod-identity. Otherwise MIC component fails while attempting to update MSI on VMSS cluster nodes
resource id 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, virtualMachineContributorRole)
  properties: {
    roleDefinitionId: virtualMachineContributorRole
    principalId: kubeletidentityObjectId
    principalType: 'ServicePrincipal'
  }
}
