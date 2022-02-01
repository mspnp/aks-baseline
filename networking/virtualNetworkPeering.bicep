targetScope = 'resourceGroup'

@minLength(1)
param localVnetName string

@minLength(79)
param remoteVirtualNetworkId string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: 'to_${last(split(remoteVirtualNetworkId, '/'))}'
  parent: virtualNetwork
  properties: {
    remoteVirtualNetwork: {
      id: remoteVirtualNetworkId
    }
    allowForwardedTraffic: false
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
  }
}
