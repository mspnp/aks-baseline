#Please chek the variables values
RGLOCATION=eastus
VNET_NAME=vnet-hub
RGNAME=rg-enterprise-networking-hubs
RGNAMESPOKES=rg-enterprise-networking-spokes
RGNAMECLUSTER=rg-cluster01
AKSNAME=myakssp

## Catch output from create-azure-ad-registrations.sh
k8sRbacAadProfileServerAppId=469eee86-4e39-4033-8500-63bb0ca672d5
k8sRbacAadProfileClientAppId=23c9eb66-2141-43fc-a668-9807e60f5161
k8sRbacAadProfileServerAppSecret=2433af5c-4e7f-46b9-b4f2-b116730fe741
k8sRbacAadProfileTennetId=15672ec6-9e15-4b37-adc0-de73835efc53

az login 
#Main Network.Build the hub. First arm template execution and catching outputs
az group create --name "${RGNAME}" --location "${RGLOCATION}"

az deployment group create --resource-group "${RGNAME}" --template-file "001-enterprise-hub-stamp (pre network-stamp).json"  --name "hub-0001" --parameters location=$RGLOCATION hubVnetName=$VNET_NAME

FIREWALL_NAME=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.firewallName.value -o tsv)

HUB_LA_RESOURCE_ID=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.hubLaResourceId.value -o tsv)

HUB_VNET_ID=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.hubVnetId.value -o tsv)

#Cluster Subnet.Build the spoke. Second arm template execution and catching outputs
az group create --name "${RGNAMESPOKES}" --location "${RGLOCATION}"

az deployment group  create --resource-group "${RGNAMESPOKES}" --template-file "002-cluster-network-stamp.json" --name "spoke-0001" --parameters location=$RGLOCATION hubLaResourceId=$HUB_LA_RESOURCE_ID hubVnetId=$HUB_VNET_ID firewallName=$FIREWALL_NAME

TARGET_VNET_RESOURCE_ID=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.targetVnetResourceId.value -o tsv)

VNET_NODEPOOL_SUBNET_NAME=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.vnetNodepoolSubnetName.value -o tsv)

VNET_NODEPOOL_SUBNET_RESOURCE_ID=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.vnetNodepoolSubnetNameResourceId.value -o tsv)

#Main Network Update. Third arm template execution and catching outputs
az deployment group create --resource-group "${RGNAME}" --template-file "003-enterprise-hub-stamp (post network-stamp).json" --name "hub-0002" --parameters location=$RGLOCATION hubVnetName=$VNET_NAME vnetNodepoolSubnetNameResourceId=$VNET_NODEPOOL_SUBNET_RESOURCE_ID

FIREWALL_NAME=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.firewallName.value -o tsv)

HUB_LA_RESOURCE_ID=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.hubLaResourceId.value -o tsv)

HUB_VNET_ID=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.hubVnetId.value -o tsv)

#AKS Service principal creation
aks_profile_clientid=$(az ad sp create-for-rbac  -n $AKSNAME --query appId -o tsv)
aks_profile_secret=$(az ad sp credential reset --name $aks_profile_clientid  --credential-description "AKSPassword" --query password -o tsv)
aks_profile_objectid=$( az ad sp show --id  $aks_profile_clientid --query objectId -o tsv)

#AKS Cluster Creation. Advance Networking. AAD identity integration.
az group create --name "${RGNAMECLUSTER}" --location "${RGLOCATION}"

az deployment group  create --resource-group "${RGNAMECLUSTER}" --template-file "004-cluster-stamp.json" --name "cluster-0001" --parameters location=$RGLOCATION targetVnetResourceId=$TARGET_VNET_RESOURCE_ID servicePrincipalProfileClientId=$aks_profile_clientid servicePrincipalProfileObjectId=$aks_profile_objectid servicePrincipalProfileSecret=$aks_profile_secret k8sRbacAadProfileServerAppId=$k8sRbacAadProfileServerAppId k8sRbacAadProfileServerAppSecret=$k8sRbacAadProfileServerAppSecret k8sRbacAadProfileClientAppId=$k8sRbacAadProfileClientAppId k8sRbacAadProfileTennetId=$k8sRbacAadProfileTennetId
