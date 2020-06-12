# This script might take about 20 minutes

# Please check the variables
RGLOCATION=eastus
RGNAME=rg-enterprise-networking-hubs
RGNAMESPOKES=rg-enterprise-networking-spokes
RGNAMECLUSTER=rg-cluster01
aksName=cluster01
tenant_guid=**Your tenant id for Identities**
main_subscription=**Your Main subscription**
APP_NAME="AksDeployerPrincipal"

#replace contosobicycle.com with your own domain
AKS_ENDUSER_NAME=aksuser@contosobicycle.com
AKS_ENDUSER_PASSWORD=**Your valid password**

k8sRbacAadProfileAdminGroupName="${aksName}-add-admin"

echo ""
echo "# Creating users and group for AAD-AKS integration. It could be in a different tenant"
echo ""

# We are going to use a new tenant to provide identity
az login  --allow-no-subscriptions -t $tenant_guid

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

#Creating service principal with minimum privilage to deploy the cluster
APP_ID=$(az ad sp create-for-rbac -n $APP_NAME --skip-assignment --query appId -o tsv)
APP_PASS=$(az ad sp credential reset --name $APP_NAME --credential-description "AKSClientSecret" --query password -o tsv)
APP_TENANT_ID=$(az account show --query tenantId -o tsv)

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

cat << EOF

NEXT STEPS
---- -----

1) Copy the following AKS CLuster parameters into the 1-cluster-stamp.sh

CLUSTER_VNET_RESOURCE_ID=${CLUSTER_VNET_RESOURCE_ID}
RGNAMECLUSTER=${RGNAMECLUSTER}
RGLOCATION=${RGLOCATION}
FIREWALL_SUBNET_RESOURCEID=${FIREWALL_SUBNET_RESOURCEID}
GATEWAY_SUBNET_RESOURCE_ID=${GATEWAY_SUBNET_RESOURCE_ID}
k8sRbacAadProfileAdminGroupObjectID=${k8sRbacAadProfileAdminGroupObjectID}
k8sRbacAadProfileTenantId=${k8sRbacAadProfileTenantId}
RGNAMESPOKES=${RGNAMESPOKES}
tenant_guid=${tenant_guid}
main_subscription=${main_subscription}
# User Parameters. Perhaps, you will need to scape ' on the password. The hay to scape is \'  
APP_ID=${APP_ID}
APP_PASS=$'${APP_PASS}'
APP_TENANT_ID=${APP_TENANT_ID}

2) Execute '1-cluster-stamp.sh'

Note: The user which will stamp the cluster will need the following minimum permissions

* On the Cluster Vnet (${CLUSTER_VNET_RESOURCE_ID})
a. Network Contributor
b. User Access Administrator

*) Role on Cluster Vnet Resource Group (${RGNAMESPOKES}). It is needed 'Microsoft.Resources/deployments/write', 
a. It is possible to create a custom role with that permission and assign to the user
b. The minimum built-in Role with that permission is 'Managed Applications Reader'
c. Network Contributor role has that permission, but also much more

*) A new resource group was created for the AKS Cluster (${RGNAMECLUSTER}). The user needs against this resource group the following roles
a. Contributor
b. User Access Administrator

EOF




