# This script might take about 20 minutes
# Please check the variables
RGLOCATION=eastus
RGNAME=rg-enterprise-networking-hubs
RGNAMESPOKES=rg-enterprise-networking-spokes
RGNAMECLUSTER=rg-cluster01
aksName=cluster01
runDate=$(date +%S%N)
spName=${aksName}-sp-${runDate}
serverAppName=${aksName}-server-${runDate}
clientAppName=${aksName}-kubectl-${runDate}
tenant_guid=**Your tenant id for Identities**
main_subscription=**Your Main subscription**
#replace contosobicycle.com with your own domain
AKS_ENDUSER_NAME=aksuser@contosobicycle.com
AKS_ENDUSER_PASSWORD=**Your valid password**

echo ""
echo "# Creating users and group for AAD-AKS integration. It could be in a different tenant"
echo ""

# We are going to use a new tenant to provide identity
az login  --allow-no-subscriptions -t $tenant_guid
#--Until change the subscription It will take about 1 minutes creating service principals

# Create the Azure AD application
k8sRbacAadProfileServerAppId=$(az ad app create --display-name "$serverAppName" --identifier-uris "https://${serverAppName}" --query appId -o tsv)

# Update the application group memebership claims
az ad app update --id $k8sRbacAadProfileServerAppId --set groupMembershipClaims=All

# Create a service principal for the Azure AD application
az ad sp create --id $k8sRbacAadProfileServerAppId

# Get the service principal secret
k8sRbacAadProfileServerAppSecret=$(az ad sp credential reset --name $k8sRbacAadProfileServerAppId  --credential-description "AKSClientSecret" --query password -o tsv)

az ad app permission add \
    --id $k8sRbacAadProfileServerAppId \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
az ad app permission grant --id $k8sRbacAadProfileServerAppId --api 00000003-0000-0000-c000-000000000000
az ad app permission admin-consent --id  $k8sRbacAadProfileServerAppId

k8sRbacAadProfileClientAppId=$(az ad app create \
    --display-name "${clientAppName}" \
    --native-app \
    --reply-urls "https://${clientAppName}" \
    --query appId -o tsv)

az ad sp create --id $k8sRbacAadProfileClientAppId

oAuthPermissionId=$(az ad app show --id $k8sRbacAadProfileServerAppId --query "oauth2Permissions[0].id" -o tsv)
az ad app permission add --id $k8sRbacAadProfileClientAppId --api $k8sRbacAadProfileServerAppId --api-permissions ${oAuthPermissionId}=Scope
az ad app permission grant --id $k8sRbacAadProfileClientAppId --api $k8sRbacAadProfileServerAppId

k8sRbacAadProfileTenantId=$(az account show --query tenantId -o tsv)

echo ""
echo "# Deploying networking"
echo ""

#back to main subscription
az login
az account set -s $main_subscription

#Main Network.Build the hub. First arm template execution and catching outputs. This might take about 6 minutes
az group create --name "${RGNAME}" --location "${RGLOCATION}"

az deployment group create --resource-group "${RGNAME}" --template-file "./networking/hub-default.json"  --name "hub-0001" --parameters \
         location=$RGLOCATION

HUB_VNET_ID=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.hubVnetId.value -o tsv)

FIREWALL_SUBNET_RESOURCEID=$(az deployment group show -g $RGNAME -n hub-0001 --query properties.outputs.hubfwSubnetResourceId.value -o tsv)

#Cluster Subnet.Build the spoke. Second arm template execution and catching outputs. This might take about 2 minutes
az group create --name "${RGNAMESPOKES}" --location "${RGLOCATION}"

az deployment group  create --resource-group "${RGNAMESPOKES}" --template-file "./networking/spoke-BU0001A0008.json" --name "spoke-0001" --parameters \
          location=$RGLOCATION \
          hubVnetResourceId=$HUB_VNET_ID

CLUSTER_VNET_RESOURCE_ID=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.clusterVnetResourceId.value -o tsv)

NODEPOOL_SUBNET_RESOURCE_ID=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)

GATEWAY_SUBNET_RESOURCE_ID=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.vnetGatewaySubnetResourceIds.value -o tsv)

#Main Network Update. Third arm template execution and catching outputs. This might take about 3 minutes

SERVICETAGS_LOCATION=$(az account list-locations --query "[?name=='${RGLOCATION}'].displayName" -o tsv | sed 's/[[:space:]]//g')
az deployment group create --resource-group "${RGNAME}" --template-file "./networking/hub-regionA.json" --name "hub-0002" --parameters \
            location=$RGLOCATION \
            nodepoolSubnetResourceIds="['$NODEPOOL_SUBNET_RESOURCE_ID']" \
            keyVaultFirewallRuleSubnetResourceIds="['$NODEPOOL_SUBNET_RESOURCE_ID','$GATEWAY_SUBNET_RESOURCE_ID']" \
            serviceTagLocation=$SERVICETAGS_LOCATION

echo ""
echo "# Deploying AKS Cluster"
echo ""

#AKS Cluster Creation. Advance Networking. AAD identity integration. This might take about 8 minutes
az group create --name "${RGNAMECLUSTER}" --location "${RGLOCATION}"

# Cluster Parameters
echo "Cluster Parameters"
echo "CLUSTER_VNET_RESOURCE_ID=${CLUSTER_VNET_RESOURCE_ID}"
echo "RGNAMECLUSTER=${RGNAMECLUSTER}"
echo "RGLOCATION=${RGLOCATION}"
echo "FIREWALL_SUBNET_RESOURCEID=${FIREWALL_SUBNET_RESOURCEID}"
echo "k8sRbacAadProfileServerAppId=${k8sRbacAadProfileServerAppId}"
echo "k8sRbacAadProfileClientAppId=${k8sRbacAadProfileClientAppId}"
echo "k8sRbacAadProfileServerAppSecret=${k8sRbacAadProfileServerAppSecret}"
echo "k8sRbacAadProfileTenantId=${k8sRbacAadProfileTenantId}"

az deployment group create --resource-group "${RGNAMECLUSTER}" --template-file "cluster-stamp.json" --name "cluster-0001" --parameters \
               location=$RGLOCATION \
               targetVnetResourceId=$CLUSTER_VNET_RESOURCE_ID \
               k8sRbacAadProfileServerAppId=$k8sRbacAadProfileServerAppId \
               k8sRbacAadProfileServerAppSecret=$k8sRbacAadProfileServerAppSecret \
               k8sRbacAadProfileClientAppId=$k8sRbacAadProfileClientAppId \
               k8sRbacAadProfileTenantId=$k8sRbacAadProfileTenantId \
               keyvaultAclAllowedSubnetResourceIds="['$FIREWALL_SUBNET_RESOURCEID']"

AKS_CLUSTER_NAME=$(az deployment group show -g $RGNAMECLUSTER -n cluster-0001 --query properties.outputs.aksClusterName.value -o tsv)

echo ""
echo "# Creating AAD Groups and users for the created cluster"
echo ""

# We are going to use a new tenant which manage the cluster identity
az login  --allow-no-subscriptions -t $tenant_guid

#Creating AAD groups which will be associated to k8s out of the box cluster roles
k8sClusterAdminAadGroupName="k8s-cluster-admin-clusterrole-${AKS_CLUSTER_NAME}"
k8sClusterAdminAadGroup=$(az ad group create --display-name ${k8sClusterAdminAadGroupName} --mail-nickname ${k8sClusterAdminAadGroupName} --query objectId -o tsv)
k8sAdminAadGroupName="k8s-admin-clusterrole-${AKS_CLUSTER_NAME}"
k8sAdminAadGroup=$(az ad group create --display-name ${k8sAdminAadGroupName} --mail-nickname ${k8sAdminAadGroupName} --query objectId -o tsv)
k8sEditAadGroupName="k8s-edit-clusterrole-${AKS_CLUSTER_NAME}"
k8sEditAadGroup=$(az ad group create --display-name ${k8sEditAadGroupName} --mail-nickname ${k8sEditAadGroupName} --query objectId -o tsv)
k8sViewAadGroupName="k8s-view-clusterrole-${AKS_CLUSTER_NAME}"
k8sViewAadGroup=$(az ad group create --display-name ${k8sViewAadGroupName} --mail-nickname ${k8sViewAadGroupName} --query objectId -o tsv)

#EXAMPLE of an User in View Group 
AKS_ENDUSR_OBJECTID=$(az ad user create --display-name $AKS_ENDUSER_NAME --user-principal-name $AKS_ENDUSER_NAME --password $AKS_ENDUSER_PASSWORD --query objectId -o tsv)
az ad group member add --group k8s-view-clusterrole --member-id $AKS_ENDUSR_OBJECTID

echo "# After cleaning up key vault in order to delete the soft delete"
echo "az keyvault purge --name kv-${AKS_CLUSTER_NAME} --location ${RGLOCATION}"

echo ""
echo "# Temporary section. It is going to be deleted in the future"
echo ""
echo "k8s-cluster-admin-clusterrole ${k8sClusterAdminAadGroup}"
echo "k8s-admin-clusterrole ${k8sAdminAadGroup}"
echo "k8s-edit-clusterrole ${k8sEditAadGroup}"
echo "k8s-view-clusterrole ${k8sViewAadGroup}"
echo "User Name:${AKS_ENDUSER_NAME} Pass:${AKS_ENDUSER_PASSWORD} objectId:${AKS_ENDUSR_OBJECTID}"
echo ""
echo "Testing role after update yaml file (cluster-settings/user-facing-cluster-role-aad-group.yaml). Execute:"
echo ""
echo "az aks get-credentials -n ${AKS_CLUSTER_NAME} -g ${RGNAMECLUSTER} --admin"
echo "kubectl apply -f ./cluster-settings/user-facing-cluster-role-aad-group.yaml"
echo "az aks get-credentials -n ${AKS_CLUSTER_NAME} -g ${RGNAMECLUSTER} --overwrite-existing"
echo "kubectl get all"
echo ""
echo "->Kubernetes will ask you to login. You will need to use the ${AKS_ENDUSER_NAME} user"