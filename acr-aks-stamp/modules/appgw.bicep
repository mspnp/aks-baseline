param location string
param appGWName string
param appGWIdentityName string
param appGWListenerCertificateSecretId string
param aksIngressCertificateSecretId string
param appGWSubnetId string
param appGWHostName string
param aksBackendDomainName string
param logAnalyticsWorkspaceName string
param trustedRootCertificatesRequired bool

var appGWPublicIpName = 'ip-${appGWName}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource appGWPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: appGWPublicIpName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource appgw 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: appGWName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { 
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', appGWIdentityName)}': {
      }
    }
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    enableHttp2: false
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    sslPolicy: {
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
      ]
      minProtocolVersion: 'TLSv1_2'
    }
    trustedRootCertificates: trustedRootCertificatesRequired ? [
      {
        name: 'root-cert-wildcard-aks-ingress'
        properties: {
          keyVaultSecretId: aksIngressCertificateSecretId
        }
      }
    ] : []
    sslCertificates: [
      {
        name: 'ssl-certificate'
        properties: {
          keyVaultSecretId: appGWListenerCertificateSecretId
        }
      }
    ]
    frontendIPConfigurations:[
      {
        name: '${appGWName}-Frontend'
        properties: {
          publicIPAddress: {
            id: appGWPublicIp.id
          }
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: '${appGWName}-Gateway'
        properties:{
          subnet: {
            id: appGWSubnetId
          } 
        }
      }
    ]
    autoscaleConfiguration:{
      minCapacity: 0
      maxCapacity: 2
    }
    frontendPorts: [
      {
        name: 'HTTPS'
        properties: {
          port: 443
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-https'
        properties:{
          protocol: 'Https'
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGWName, '${appGWName}-Frontend')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGWName, 'HTTPS')
          }
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGWName, 'ssl-certificate')
          }
          hostName: appGWHostName
          hostNames: []
          requireServerNameIndication: true
        }
      }
    ]
    requestRoutingRules: [
      {
        name: '${appGWName}-RoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGWName, 'listener-https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGWName, aksBackendDomainName)
          } 
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGWName, '${appGWName}-HttpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'aks-probe'
        properties: {
          protocol: 'Https'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {}
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: '${appGWName}-HttpSettings'
        properties: {
          requestTimeout: 20
          protocol: 'Https'
          port: 443
          pickHostNameFromBackendAddress: true
          cookieBasedAffinity: 'Disabled'
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGWName, 'aks-probe')
          }
          trustedRootCertificates: trustedRootCertificatesRequired ? [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', appGWName, 'root-cert-wildcard-aks-ingress')
            }
          ] : []
        }
      }
    ]
    backendAddressPools: [
      {
        name: aksBackendDomainName
        properties: {
          backendAddresses: [
            {
              fqdn: aksBackendDomainName
            }
          ]
        }
      }
    ]
  }
}

resource appGWDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Microsoft.Insights'
  scope: appgw
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
  }
}
