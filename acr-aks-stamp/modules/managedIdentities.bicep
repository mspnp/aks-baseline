@secure()
param aksControlPlaneIdentityName string
param appGWIdentityName string
param aksIngressIdentityName string
param location string

// The control plane identity used by the cluster. Used for networking access (VNET joining and DNS updating)
resource aksControlPlaneIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: aksControlPlaneIdentityName
  location: location
}

// User Managed Identity that App Gateway is assigned. Used for Azure Key Vault Access.
resource appGWIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: appGWIdentityName
  location: location
}

// User Managed Identity for the cluster's ingress controller pods. Used for Azure Key Vault Access.
resource aksIngressIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: aksIngressIdentityName
  location: location
}

output aksIngressIdentityPrincipalId string = aksIngressIdentity.properties.principalId
output appGWIdentityPrincipalId string = appGWIdentity.properties.principalId
output aksControlPlaneIdentityPrincipalId string = aksControlPlaneIdentity.properties.principalId
