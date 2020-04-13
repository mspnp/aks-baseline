# Azure Kubernetes Services

This is a WIP.

## Steps

1. Deploy Azure AD Service Principal
1. Deploy Azure AD App Registrations

1. Build the hub:  
   It is possible to change location and rg name

```
RGLOCATION=eastus
RGNAME=rg-enterprise-networking-hubs
az group create --name "${RGNAME}" --location "${RGLOCATION}"

az deployment group create --resource-group "${RGNAME}" --template-file "001-enterprise-hub-stamp (pre network-stamp).json"  --name "hub-0001"
```

- This might take about 5 minutes

The script generate output which are the input for the next script. It will look like:

```
"firewallName": {
        "type": "String",
        "value": "fw-eastus2-hub"
      },
      "hubLaResourceId": {
        "type": "String",
        "value": "/subscriptions/a012a8b0-522a-4f59-81b6-aa0361eb9387/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.OperationalInsights/workspaces/la-networking-hub-63eldsvto2mzm"
      },
      "hubVnetId": {
        "type": "String",
        "value": "/subscriptions/a012a8b0-522a-4f59-81b6-aa0361eb9387/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub"
      }
    },
```

1. Build the spoke:
   The template parameters must be updated with the data generated as output from the previous execution

```
RGNAME=rg-enterprise-networking-spokes

az group create --name "${RGNAME}" --location "${RGLOCATION}"

az deployment group  create --resource-group "${RGNAME}" --template-file "002-cluster-network-stamp.json" --name "spoke-0001"
```

This might take about 1 minute

It will generate outputs like:

```
 "outputs": {
      "targetVnetResourceId": {
        "type": "String",
        "value": "/subscriptions/a012a8b0-522a-4f59-81b6-aa0361eb9387/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub-spoke-BU0001A0008-00"
      },
      "vnetNodepoolSubnetName": {
        "type": "String",
        "value": "snet-clusternodes"
      },
      "vnetNodepoolSubnetNameResourceId": {
        "type": "String",
        "value": "/subscriptions/a012a8b0-522a-4f59-81b6-aa0361eb9387/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub-spoke-BU0001A0008-00/subnets/snet-clusternodes"
      }
    },
```

1. Update template parameters  
   NOTE: The RGNAME must be the same than step 1

```
RGNAME=rg-enterprise-networking-hubs

az deployment group create --resource-group "${RGNAME}"  --template-file "003-enterprise-hub-stamp (post network-stamp).json" --name "hub-0002"

```

This might take about 2 minutes

1. Stamp the cluster

Your user need to be able to assign permission in the subcription. It is needed on the first resource into the ARM template.

Two service principal are needed:

1. One for the AKS Cluster
   Your user need to have permisions to assign to this service principal "Network Contributor" on the AKS subnet.
2. One in order to use [AD as identity provider](https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli)

It could be than in a new tenant

```
az login  --allow-no-subscriptions -t **Your new tenant**
#It is only a name for identities
aksname="myakscluster"

# Create the Azure AD application
serverApplicationId=$(az ad app create --display-name "${aksname}Server" --identifier-uris "https://${aksname}Server" --query appId -o tsv)

# Update the application group memebership claims
az ad app update --id $serverApplicationId --set groupMembershipClaims=All

# Create a service principal for the Azure AD application
az ad sp create --id $serverApplicationId

# Get the service principal secret
serverApplicationSecret=$(az ad sp credential reset --name $serverApplicationId  --credential-description "AKSPassword" --query password -o tsv)

az ad app permission add \
    --id $serverApplicationId \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
az ad app permission grant --id $serverApplicationId --api 00000003-0000-0000-c000-000000000000
az ad app permission admin-consent --id  $serverApplicationId

clientApplicationId=$(az ad app create \
    --display-name "${aksname}Client" \
    --native-app \
    --reply-urls "https://${aksname}Client" \
    --query appId -o tsv)

az ad sp create --id $clientApplicationId

oAuthPermissionId=$(az ad app show --id $serverApplicationId --query "oauth2Permissions[0].id" -o tsv)
az ad app permission add --id $clientApplicationId --api $serverApplicationId --api-permissions ${oAuthPermissionId}=Scope
az ad app permission grant --id $clientApplicationId --api $serverApplicationId

tenantId=$(az account show --query tenantId -o tsv)

# Outputs
echo $serverApplicationId
echo $serverApplicationSecret
echo $clientApplicationId
```

`az group deployment create --resource-group rg-cluster01 --template-file "004-cluster-stamp.json" --name "cluster-0001" --parameters servicePrincipalProfileClientId=REPLACEME location=eastus2 targetVnetResourceId=/subscriptions/REPLACEME/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub-spoke-BU0001A0008-00 servicePrincipalProfileObjectId=REPLACEME servicePrincipalProfileSecret=REPLACEME k8sRbacAadProfileServerAppId=REPLACEME k8sRbacAadProfileServerAppSecret=REPLACEME k8sRbacAadProfileClientAppId=REPLACEME k8sRbacAadProfileTennetId=REPLACEME` - Adjust parameters as needed - This might take about 8 minutes

NOTE: If you don't have permissions to assign permission, the service principal with the required permission must be provided to you in order to bypass the issue:

```
AKSNAME=akssp
​
aksclientid=$(az ad sp create-for-rbac  -n $AKSNAME --role "Network Contributor" --scopes '/subscriptions/a012a8b0-522a-4f59-81b6-aa0361eb9387/resourceGroups/far-rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub-spoke-BU0001A0008-00' --query appId -o tsv)​
echo $aksclientid​
​
akssecret=$(az ad sp credential reset --name $aksclientid  --credential-description "AKSPassword" --query password -o tsv)​
echo $akssecret​
​
aksobjectid=$( az ad sp show --id  $aksclientid --query objectId -o tsv)​
echo $aksobjectid​
```

### Clean up

- Leave the Service Principal and App Registrations in Azure AD
- Delete the cluster resource group contents
- Delete the spoke resource group contents
- Delete the hub resource group contents
