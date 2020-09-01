#!/usr/bin/env bash

set -e

# This script might take about 20 minutes
# Please check the variables
LOCATION=$1
RGNAMEHUB=$2
RGNAMESPOKES=$3
RGNAMECLUSTER=$4
TENANT_ID=$5
MAIN_SUBSCRIPTION=$6

AKS_ADMIN_NAME=aksadminuser
AKS_ENDUSER_NAME=aksuser
AKS_ENDUSER_PASSWORD=ChangeMebu0001a0008AdminChangeMe

K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_NAME="add-to-bu0001a000800-cluster-admin"

__usage="
    [-c RGNAMECLUSTER]
    [-h RGNAMEHUB]
    [-l LOCATION]
    [-s MAIN_SUBSCRIPTION]
    [-t TENANT_ID]
    [-p RGNAMESPOKES]
"

usage() {
    echo "usage: ${0##*/}"
    echo "${__usage/[[:space:]]/}"
    exit 1
}

while getopts "c:h:l:s:t:p:" opt; do
    case $opt in
    c)  RGNAMECLUSTER="${OPTARG}";;
    h)  RGNAMEHUB="${OPTARG}";;
    l)  LOCATION="${OPTARG}";;
    s)  MAIN_SUBSCRIPTION="${OPTARG}";;
    t)  TENANT_ID="${OPTARG}";;
    p)  RGNAMESPOKES="${OPTARG}";;
    *)  usage;;
    esac
done
shift $(( $OPTIND - 1 ))

if [ $OPTIND = 1 ]; then
    usage
    exit 0
fi

echo ""
echo "# Creating users and group for AAD-AKS integration. It could be in a different tenant"
echo ""

# We are going to use a new tenant to provide identity
az login  --allow-no-subscriptions -t $TENANT_ID

K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
AKS_ADMIN_NAME=${AKS_ADMIN_NAME}'@'${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME}
AKS_ENDUSER_NAME=${AKS_ENDUSER_NAME}'@'${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME}

#--Create identities needed for AKS-AAD integration
AKS_ADMIN_OBJECTID=$(az ad user create --display-name $AKS_ADMIN_NAME --user-principal-name $AKS_ADMIN_NAME --force-change-password-next-login  --password $AKS_ENDUSER_PASSWORD --query objectId -o tsv)
K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID=$(az ad group create --display-name ${K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_NAME} --mail-nickname ${K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_NAME} --query objectId -o tsv)
az ad group member add --group $K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_NAME --member-id $AKS_ADMIN_OBJECTID
K8S_RBAC_AAD_PROFILE_TENANTID=$(az account show --query tenantId -o tsv)

echo ""
echo "# Deploying networking"
echo ""

#back to main subscription
az login
az account set -s $MAIN_SUBSCRIPTION

#Main Network.Build the hub. First arm template execution and catching outputs. This might take about 6 minutes
az group create --name "${RGNAMEHUB}" --location "${LOCATION}"

az deployment group create --resource-group "${RGNAMEHUB}" --template-file "../../networking/hub-default.json"  --name "hub-0001" --parameters \
         location=$LOCATION

HUB_VNET_ID=$(az deployment group show -g $RGNAMEHUB -n hub-0001 --query properties.outputs.hubVnetId.value -o tsv)

#Cluster Subnet.Build the spoke. Second arm template execution and catching outputs. This might take about 2 minutes
az group create --name "${RGNAMESPOKES}" --location "${LOCATION}"

az deployment group  create --resource-group "${RGNAMESPOKES}" --template-file "../../networking/spoke-BU0001A0008.json" --name "spoke-0001" --parameters \
          location=$LOCATION \
          hubVnetResourceId=$HUB_VNET_ID 

export TARGET_VNET_RESOURCE_ID=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.clusterVnetResourceId.value -o tsv)

NODEPOOL_SUBNET_RESOURCE_IDS=$(az deployment group show -g $RGNAMESPOKES -n spoke-0001 --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)

#Main Network Update. Third arm template execution and catching outputs. This might take about 3 minutes

az deployment group create --resource-group "${RGNAMEHUB}" --template-file "../../networking/hub-regionA.json" --name "hub-0002" --parameters \
            location=$LOCATION \
            nodepoolSubnetResourceIds="['$NODEPOOL_SUBNET_RESOURCE_IDS']"

echo ""
echo "# Preparing cluster parameters"
echo ""

az group create --name "${RGNAMECLUSTER}" --location "${LOCATION}"

cat << EOF

NEXT STEPS
---- -----

./1-cluster-stamp.sh $LOCATION $RGNAMECLUSTER $RGNAMESPOKES $TENANT_ID $MAIN_SUBSCRIPTION $TARGET_VNET_RESOURCE_ID $K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID $K8S_RBAC_AAD_PROFILE_TENANTID $AKS_ENDUSER_NAME $AKS_ENDUSER_PASSWORD

EOF




