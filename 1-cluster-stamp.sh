# This script might take about 10 minutes

# Please check the variables
tenant_guid=**Your tenant id for Identities**
main_subscription=**Your Main subscription**
AKS_ENDUSER_NAME=aksuser1@contosobicycle.com
AKS_ENDUSER_PASSWORD=**Your valid password**

# Cluster Parameters. 
# Copy from pre-cluster-stump.sh output
CLUSTER_VNET_RESOURCE_ID=
RGNAMECLUSTER=
RGLOCATION=
FIREWALL_SUBNET_RESOURCEID=
GATEWAY_SUBNET_RESOURCE_ID=
k8sRbacAadProfileAdminGroupObjectID=
k8sRbacAadProfileTenantId=

# Used for services that support native geo-redundancy (Azure Container Registry)
# Ideally should be the paired region of $RGLOCATION
GEOREDUNDANCY_LOCATION=centralus

# User Parameters. 
# Copy from pre-cluster-stump.sh output
APP_ID=
APP_PASS=
APP_TENANT_ID=

# Login with the service principal created with minimum privilege. It is a demo approach.
# A real user with the correct privilege should login
az login --service-principal --username $APP_ID --password $APP_PASS --tenant $APP_TENANT_ID

echo ""
echo "# Deploying AKS Cluster"
echo ""

#AKS Cluster Creation. Advance Networking. AAD identity integration. This might take about 8 minutes
az deployment group create --resource-group "${RGNAMECLUSTER}" --template-file "cluster-stamp.json" --name "cluster-0001" --parameters \
               location=$RGLOCATION \
               geoRedundancyLocation=$GEOREDUNDANCY_LOCATION \
               targetVnetResourceId=$CLUSTER_VNET_RESOURCE_ID \
               k8sRbacAadProfileAdminGroupObjectID=$k8sRbacAadProfileAdminGroupObjectID \
               k8sRbacAadProfileTenantId=$k8sRbacAadProfileTenantId \
               keyvaultAclAllowedSubnetResourceIds="['$FIREWALL_SUBNET_RESOURCEID', '$GATEWAY_SUBNET_RESOURCE_ID']"

AKS_CLUSTER_NAME=$(az deployment group show -g $RGNAMECLUSTER -n cluster-0001 --query properties.outputs.aksClusterName.value -o tsv)

echo ""
echo "# Creating AAD Groups and users for the created cluster"
echo ""

# We are going to use a the new tenant which manage the cluster identity
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

cat << EOF

NEXT STEPS
---- -----

# Temporary section. It is going to be deleted in the future. Testing k8sRBAC-AAD Groups

k8s-cluster-admin-clusterrole ${k8sClusterAdminAadGroup}
k8s-admin-clusterrole ${k8sAdminAadGroup}
k8s-edit-clusterrole ${k8sEditAadGroup}
k8s-view-clusterrole ${k8sViewAadGroup}
User Name:${AKS_ENDUSER_NAME} Pass:${AKS_ENDUSER_PASSWORD} objectId:${AKS_ENDUSR_OBJECTID}

Testing role after update yaml file (cluster-settings/user-facing-cluster-role-aad-group.yaml). Execute:

az login
az account set -s $main_subscription
az aks get-credentials -n ${AKS_CLUSTER_NAME} -g ${RGNAMECLUSTER} --admin
kubectl apply -f ./cluster-settings/user-facing-cluster-role-aad-group.yaml
az aks get-credentials -n ${AKS_CLUSTER_NAME} -g ${RGNAMECLUSTER} --overwrite-existing
kubectl get all

->Kubernetes will ask you to login. You will need to use the ${AKS_ENDUSER_NAME} user

# Clean up resources. Execute:

deleteResourceGroups.sh

EOF

