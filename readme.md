# Azure Kubernetes Services

This is a WIP.

## Steps

1. Deploy Azure AD Service Principal
1. Deploy Azure AD App Registrations
1. Build the hub: `az group deployment create --resource-group rg-enterprise-networking-hubs --template-file "001-enterprise-hub-stamp (pre network-stamp).json" --name "hub-0001"` - This might take about 5 minutes
1. Build the spoke: `az group deployment create --resource-group rg-enterprise-networking-spokes --template-file "002-cluster-network-stamp.json" --name "spoke-0001"`- update parameters, provide them in a file, or on the cli - This might take about 1 minute
1. Update the hub stamp to include AKS FW entries: `az group deployment create --resource-group rg-enterprise-networking-hubs --template-file "003-enterprise-hub-stamp (post network-stamp).json" --name "hub-0002"` - This might take about 2 minutes
1. Stamp the cluster: `az group deployment create --resource-group rg-cluster01 --template-file "004-cluster-stamp.json" --name "cluster-0001" --parameters servicePrincipalProfileClientId=REPLACEME location=eastus2 targetVnetResourceId=/subscriptions/REPLACEME/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub-spoke-BU0001A0008-00 servicePrincipalProfileObjectId=REPLACEME servicePrincipalProfileSecret=REPLACEME k8sRbacAadProfileServerAppId=REPLACEME k8sRbacAadProfileServerAppSecret=REPLACEME k8sRbacAadProfileClientAppId=REPLACEME k8sRbacAadProfileTennetId=REPLACEME` - Adjust parameters as needed - This might take about 8 minutes

### Clean up

* Leave the Service Principal and App Registrations in Azure AD
* Delete the cluster resource group contents
* Delete the spoke resource group contents
* Delete the hub resource group contents
