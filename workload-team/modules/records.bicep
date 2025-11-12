targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Location of the regional resources.')
param location string

@description('Resource Id of the Private Endpoint Network Interface.')
param targetNetworkInterfaceResourceId string

@description('The AKS api server private fqdn subdomain')
param fqdnSubdomain string

/*** EXISTING RESOURCES ***/

resource pdzMc 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
    name: 'privatelink.${location}.azmk8s.io'
}

/*** RESOURCES ***/

resource aksApiServerDomainName 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: pdzMc
  name: fqdnSubdomain
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: reference(targetNetworkInterfaceResourceId, '2025-05-01', 'Full').properties.ipConfigurations[0].properties.privateIPAddress
      }
    ]
  }
}
