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
APP_NAME="AksDeployerPrincipal"

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
            keyVaultFirewallRuleSubnetResourceIds="['$NODEPOOL_SUBNET_RESOURCE_ID']" \
            serviceTagLocation=$SERVICETAGS_LOCATION

echo ""
echo "# Preparing cluster parameters"
echo ""

az group create --name "${RGNAMECLUSTER}" --location "${RGLOCATION}"

cat << EOF

NEXT STEPS
---- -----

1) Copy the following AKS CLuster parameters into the 1-cluster-stamp.sh

CLUSTER_VNET_RESOURCE_ID=${CLUSTER_VNET_RESOURCE_ID}
RGNAMECLUSTER=${RGNAMECLUSTER}
RGLOCATION=${RGLOCATION}
FIREWALL_SUBNET_RESOURCEID=${FIREWALL_SUBNET_RESOURCEID}
GATEWAY_SUBNET_RESOURCE_ID=${GATEWAY_SUBNET_RESOURCE_ID}
k8sRbacAadProfileServerAppId=${k8sRbacAadProfileServerAppId}
k8sRbacAadProfileClientAppId=${k8sRbacAadProfileClientAppId}
k8sRbacAadProfileServerAppSecret=${k8sRbacAadProfileServerAppSecret}
k8sRbacAadProfileTenantId=${k8sRbacAadProfileTenantId}

2) The user which will stamp the cluster will need the following minimum permissions

2.1) On the Cluster Vnet (${CLUSTER_VNET_RESOURCE_ID})
a. Network Contributor
b. User Access Administrator

2.2) Role on Cluster Vnet Resource Group (${RGNAMESPOKES}). It is needed 'Microsoft.Resources/deployments/write', 
a. It is possible to create a custom role with that permission and assign to the user
b. The minimum built-in Role with that permission is 'Managed Applications Reader'
c. Network Contributor role has that permission, but also much more

2.3) A new resource group was created for the AKS Cluster (${RGNAMECLUSTER}). The user needs against this resource group the following roles
a. Contributor
b. User Access Administrator

3) Please login with the selected user

4) Execute '1-cluster-stamp.sh'

EOF

#Creating service principal with minimum privilage to deploy the cluster
APP_ID=$(az ad sp create-for-rbac -n $APP_NAME --skip-assignment --query appId -o tsv)
APP_PASS=$(az ad sp credential reset --name $APP_NAME --credential-description "AKSClientSecret" --query password -o tsv)
APP_TENANT_ID=$(az account show --query tenantId -o tsv)

# User Parameters.
echo "User Parameters . Copy into the 1-cluster-stamp.sh"
echo "APP_ID=${APP_ID}"
echo "APP_PASS=${APP_PASS}"
echo "APP_TENANT_ID=${APP_TENANT_ID}"

# Deploy RBAC for resources after AAD propagation
until az ad sp show --id ${APP_ID} &> /dev/null ; do echo "Waiting for AAD propagation" && sleep 5; done

#Roles on Cluster Vnet
az role assignment create  --assignee $APP_ID --role 'Network Contributor' --scope $CLUSTER_VNET_RESOURCE_ID

az role assignment create  --assignee $APP_ID --role 'User Access Administrator' --scope $CLUSTER_VNET_RESOURCE_ID

#Roles on the NEW resource group for the AKS cluster
RGNAMECLUSTER_RESOURCE_ID=$(az group show -n ${RGNAMECLUSTER} --query id -o tsv)

az role assignment create  --assignee $APP_ID --role 'Contributor' --scope ${RGNAMECLUSTER_RESOURCE_ID}

az role assignment create  --assignee $APP_ID --role 'User Access Administrator' --scope ${RGNAMECLUSTER_RESOURCE_ID}

# Role on Cluster Vnet Resource Group (It is needed 'Microsoft.Resources/deployments/write'). 
# We will use 'Network Contributor', but it can be reduced 
RGNAMESPOKES_RESOURCE_ID=$(az group show -n ${RGNAMESPOKES} --query id -o tsv)

az role assignment create  --assignee $APP_ID --role 'Network Contributor' --scope $RGNAMESPOKES_RESOURCE_ID




