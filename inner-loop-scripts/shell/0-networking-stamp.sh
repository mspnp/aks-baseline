# This script might take about 20 minutes
# Please check the variables
RGLOCATION=eastus
RGNAME=rg-enterprise-networking-hubs
RGNAMESPOKES=rg-enterprise-networking-spokes
RGNAMECLUSTER=rg-cluster01
aksName=cluster01
tenant_guid=**Your tenant id for Identities**
main_subscription=**Your Main subscription**

AKS_ENDUSER_NAME=aksuser
AKS_ENDUSER1_NAME=aksuser1
AKS_ENDUSER_PASSWORD=**Your valid password**

k8sRbacAadProfileAdminGroupName="${aksName}-add-admin"

echo ""
echo "# Creating users and group for AAD-AKS integration. It could be in a different tenant"
echo ""

# We are going to use a new tenant to provide identity
az login  --allow-no-subscriptions -t $tenant_guid

K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME=$(az ad signed-in-user show --query 'userPrincipalName' | cut -d '@' -f 2 | sed 's/\"//')
AKS_ENDUSER_NAME=${AKS_ENDUSER_NAME}'@'${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME}
AKS_ENDUSER1_NAME=${AKS_ENDUSER1_NAME}'@'${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME}

#--Create identities needed for AKS-AAD integration
AKS_ENDUSR_OBJECTID=$(az ad user create --display-name $AKS_ENDUSER_NAME --user-principal-name $AKS_ENDUSER_NAME --password $AKS_ENDUSER_PASSWORD --query objectId -o tsv)
k8sRbacAadProfileAdminGroupObjectID=$(az ad group create --display-name ${k8sRbacAadProfileAdminGroupName} --mail-nickname ${k8sRbacAadProfileAdminGroupName} --query objectId -o tsv)
az ad group member add --group $k8sRbacAadProfileAdminGroupName --member-id $AKS_ENDUSR_OBJECTID
k8sRbacAadProfileTenantId=$(az account show --query tenantId -o tsv)

echo ""
echo "# Deploying networking"
echo ""

#back to main subscription
az login
az account set -s $main_subscription

#Main Network.Build the hub. First arm template execution and catching outputs. This might take about 6 minutes
az group create --name "${RGNAME}" --location "${RGLOCATION}"

az deployment group create --resource-group "${RGNAME}" --template-file "../../networking/hub-default.json"  --name "hub-0001" --parameters \
         location=$RGLOCATION

HUB_VNET_ID=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.hubVnetId.value -o tsv)

#Cluster Subnet.Build the spoke. Second arm template execution and catching outputs. This might take about 2 minutes
az group create --name "${RGNAMESPOKES}" --location "${RGLOCATION}"

az deployment group  create --resource-group "${RGNAMESPOKES}" --template-file "../../networking/spoke-BU0001A0008.json" --name "spoke-0001" --parameters \
          location=$RGLOCATION \
          hubVnetResourceId=$HUB_VNET_ID 

CLUSTER_VNET_RESOURCE_ID=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.clusterVnetResourceId.value -o tsv)

NODEPOOL_SUBNET_RESOURCE_ID=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)

#Main Network Update. Third arm template execution and catching outputs. This might take about 3 minutes

SERVICETAGS_LOCATION=$(az account list-locations --query "[?name=='${RGLOCATION}'].displayName" -o tsv | sed 's/[[:space:]]//g')
az deployment group create --resource-group "${RGNAME}" --template-file "../../networking/hub-regionA.json" --name "hub-0002" --parameters \
            location=$RGLOCATION \
            nodepoolSubnetResourceIds="['$NODEPOOL_SUBNET_RESOURCE_ID']"

echo ""
echo "# Preparing cluster parameters"
echo ""

az group create --name "${RGNAMECLUSTER}" --location "${RGLOCATION}"

cat << EOF

NEXT STEPS
---- -----

1) Copy the following AKS CLuster parameters into the 1-cluster-stamp.sh

AKS_ENDUSER_NAME=${AKS_ENDUSER1_NAME}
AKS_ENDUSER_PASSWORD=${AKS_ENDUSER_PASSWORD}
CLUSTER_VNET_RESOURCE_ID=${CLUSTER_VNET_RESOURCE_ID}
RGNAMECLUSTER=${RGNAMECLUSTER}
RGLOCATION=${RGLOCATION}
k8sRbacAadProfileAdminGroupObjectID=${k8sRbacAadProfileAdminGroupObjectID}
k8sRbacAadProfileTenantId=${k8sRbacAadProfileTenantId}
RGNAMESPOKES=${RGNAMESPOKES}
tenant_guid=${tenant_guid}
main_subscription=${main_subscription}

EOF




