targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The hub\'s VNet resource Id')
@minLength(2)
param hubVNetResourceId string

@description('The spokes\'s VNet name')
@minLength(2)
param spokesVNetName string

@description('The spokes\'s resource group')
@minLength(1)
param rgSpokes string

/*** EXISTING RESOURCES ***/

@description('The spoke\'s VNet')
resource spokesVNet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: spokesVNetName
  scope: resourceGroup(rgSpokes)
}

/*** RESOURCES ***/

@description('Hub-to-spoke peering.')
resource hubsSpokesVirtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${last(split(hubVNetResourceId, '/'))}/hub-to-${spokesVNetName}'
  properties: {
    remoteVirtualNetwork: {
      id: spokesVNet.id
    }
    allowForwardedTraffic: false
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
  }
}
