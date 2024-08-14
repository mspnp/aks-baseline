using 'cluster-stamp.bicep'

param location = 'eastus2'

param targetVnetResourceId = '/subscriptions/[subscription id]/resourceGroups/rg-enterprise-networking-spokes-[region]/providers/Microsoft.Network/virtualNetworks/vnet-hub-spoke-BU0001A0008-00'

param clusterAdminMicrosoftEntraGroupObjectId = '[guid--security-group-objectid-that-will-become-cluster-admin]'

param a0008NamespaceReaderMicrosoftEntraGroupObjectId = '[guid--security-group-objectid-that-will-become-namespace-a0008-reader]'

param k8sControlPlaneAuthorizationTenantId = '[guid--your-cluster-APIs-authorization-tenant-ID]'

param appGatewayListenerCertificate = '[base64 cert data]'

param aksIngressControllerCertificate = '[base64 public cert data]'

param clusterAuthorizedIPRanges = '[array of IP ranges, like [\'168.196.25.0/24\',\'73.140.245.0/28\', AzureFirewallIP/32] ]'

param domainName = '[the value of DOMAIN_NAME_AKS_BASELINE (e.g. contoso.com)]'

param gitOpsBootstrappingRepoHttpsUrl = 'https://github.com/mspnp/aks-baseline'
