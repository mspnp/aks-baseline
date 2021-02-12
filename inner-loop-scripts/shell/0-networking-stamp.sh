#!/usr/bin/env bash

set -e

# This script might take about 20 minutes
# Please check the variables
LOCATION=$1
RGNAMEHUB=$2
RGNAMESPOKES=$3
RGNAMECLUSTER1=$4
RGNAMECLUSTER2=$5
TENANTID_K8SRBAC=$6
MAIN_SUBSCRIPTION=$7
RGNAME_FRONT_DOOR=$8
CLUSTER_SUBDOMAIN1=$9
CLUSTER_SUBDOMAIN2=${10}

AKS_ADMIN_NAME=bu0001a0042-admin
AKS_ENDUSER_NAME=aksuser
AKS_ENDUSER_PASSWORD=ChangeMebu0001a0008AdminChangeMe

AADOBJECTNAME_GROUP_CLUSTERADMIN="aad-to-bu0001a004200-cluster-admin"

__usage="
    [-c RGNAMECLUSTER1]
    [-d RGNAMECLUSTER2]
    [-h RGNAMEHUB]
    [-l LOCATION]
    [-s MAIN_SUBSCRIPTION]
    [-t TENANTID_K8SRBAC]
    [-p RGNAMESPOKES]
    [-f RGNAME_FRONT_DOOR]
    [-m CLUSTER_SUBDOMAIN1]
    [-n CLUSTER_SUBDOMAIN2]
"

usage() {
    echo "usage: ${0##*/}"
    echo "${__usage/[[:space:]]/}"
    exit 1
}

while getopts "c:d:h:l:s:t:p:f:m:n:" opt; do
    case $opt in
    c)  RGNAMECLUSTER1="${OPTARG}";;
    d)  RGNAMECLUSTER2="${OPTARG}";;
    h)  RGNAMEHUB="${OPTARG}";;
    l)  LOCATION="${OPTARG}";;
    s)  MAIN_SUBSCRIPTION="${OPTARG}";;
    t)  TENANTID_K8SRBAC="${OPTARG}";;
    p)  RGNAMESPOKES="${OPTARG}";;
    f)  RGNAME_FRONT_DOOR="${OPTARG}";;
    m)  CLUSTER_SUBDOMAIN1="${OPTARG}";;
    n)  CLUSTER_SUBDOMAIN2="${OPTARG}";;
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
az login  --allow-no-subscriptions -t $TENANTID_K8SRBAC

K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
AKS_ADMIN_NAME=${AKS_ADMIN_NAME}'@'${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME}
AKS_ENDUSER_NAME=${AKS_ENDUSER_NAME}'@'${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME}

#--Create identities needed for AKS-AAD integration
AKS_ADMIN_OBJECTID=$(az ad user create --display-name $AKS_ADMIN_NAME --user-principal-name $AKS_ADMIN_NAME --force-change-password-next-login  --password $AKS_ENDUSER_PASSWORD --query objectId -o tsv)
AADOBJECTID_GROUP_CLUSTERADMIN=$(az ad group create --display-name ${AADOBJECTNAME_GROUP_CLUSTERADMIN} --mail-nickname ${AADOBJECTNAME_GROUP_CLUSTERADMIN} --query objectId -o tsv)
az ad group member add --group $AADOBJECTNAME_GROUP_CLUSTERADMIN --member-id $AKS_ADMIN_OBJECTID
K8S_RBAC_AAD_PROFILE_TENANTID=$(az account show --query tenantId -o tsv)

echo ""
echo "# Deploying networking"
echo ""

#back to main subscription
az login
az account set -s $MAIN_SUBSCRIPTION
TENANTID_AZURERBAC=$(az account show --query tenantId -o tsv)

#Main Network.Build the hub. First arm template execution and catching outputs. This might take about 6 minutes
az group create -n "${RGNAMEHUB}" -l "${LOCATION}"

az deployment group create -g "${RGNAMEHUB}" -f "../../networking/hub-default.json"  -n "hub-0001" -p \
         location=$LOCATION

HUB_VNET_ID=$(az deployment group show -g $RGNAMEHUB -n hub-0001 --query properties.outputs.hubVnetId.value -o tsv)

#Cluster Subnet.Build the spoke. Second arm template execution and catching outputs. This might take about 2 minutes
az group create -n "${RGNAMESPOKES}" -l "${LOCATION}"

az deployment group create -g "${RGNAMESPOKES}" -f "../../networking/spoke-BU0001A0042.json" -n "spoke-BU0001A0042-03" -p \
          location=$LOCATION \
          hubVnetResourceId=$HUB_VNET_ID  \
          appInstanceId="03" \
          clusterVNetAddressPrefix="10.243.0.0/16" \
          clusterNodesSubnetAddressPrefix="10.243.0.0/22" \
          clusterIngressServicesSubnetAdressPrefix="10.243.4.0/28" \
          applicationGatewaySubnetAddressPrefix="10.243.4.16/28" 

RESOURCE_ID_VNET1=$(az deployment group show -g $RGNAMESPOKES -n spoke-BU0001A0042-03 --query properties.outputs.clusterVnetResourceId.value -o tsv)

NODEPOOL_SUBNET_RESOURCE_IDS_SPOKE_BU0001A0042_03=$(az deployment group show -g $RGNAMESPOKES -n spoke-BU0001A0042-03 --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)

SUBDOMAIN_BU0001A0042_03=$(az deployment group show -g $RGNAMESPOKES -n spoke-BU0001A0042-03 --query properties.outputs.subdomainName.value -o tsv)

APPGW_FQDN_BU0001A0042_03=$(az deployment group show -g $RGNAMESPOKES -n  spoke-BU0001A0042-03 --query properties.outputs.appGwFqdn.value -o tsv)

az deployment group  create -g "${RGNAMESPOKES}" -f "../../networking/spoke-BU0001A0042.json" -n "spoke-BU0001A0042-04" -p \
          location=$LOCATION \
          hubVnetResourceId=$HUB_VNET_ID  \
          appInstanceId="04" \
          clusterVNetAddressPrefix="10.244.0.0/16" \
          clusterNodesSubnetAddressPrefix="10.244.0.0/22" \
          clusterIngressServicesSubnetAdressPrefix="10.244.4.0/28" \
          applicationGatewaySubnetAddressPrefix="10.244.4.16/28" 

RESOURCE_ID_VNET2=$(az deployment group show -g $RGNAMESPOKES -n spoke-BU0001A0042-04 --query properties.outputs.clusterVnetResourceId.value -o tsv)

NODEPOOL_SUBNET_RESOURCE_IDS_SPOKE_BU0001A0042_04=$(az deployment group show -g $RGNAMESPOKES -n spoke-BU0001A0042-04 --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)

SUBDOMAIN_BU0001A0042_04=$(az deployment group show -g $RGNAMESPOKES -n spoke-BU0001A0042-04 --query properties.outputs.subdomainName.value -o tsv)

APPGW_FQDN_BU0001A0042_04=$(az deployment group show -g $RGNAMESPOKES -n  spoke-BU0001A0042-04 --query properties.outputs.appGwFqdn.value -o tsv)

#Main Network Update. Third arm template execution and catching outputs. This might take about 3 minutes

az deployment group create -g "${RGNAMEHUB}" -f "../../networking/hub-regionA.json" -n "hub-0002" -p \
            location=$LOCATION \
            nodepoolSubnetResourceIds="['${NODEPOOL_SUBNET_RESOURCE_IDS_SPOKE_BU0001A0042_03}','${NODEPOOL_SUBNET_RESOURCE_IDS_SPOKE_BU0001A0042_04}']"

echo ""
echo "# Preparing cluster parameters"
echo ""

az group create -n "${RGNAMECLUSTER1}" --location "${LOCATION}"
az group create -n "${RGNAMECLUSTER2}" --location "${LOCATION}"

cat << EOF

NEXT STEPS
---- -----
Generate certificate for:

$APPGW_FQDN_BU0001A0042_03

$APPGW_FQDN_BU0001A0042_04

then execute:

./1-cluster-stamp.sh $LOCATION $RGNAMECLUSTER1 $RGNAMECLUSTER2 $RGNAMESPOKES $TENANTID_AZURERBAC $MAIN_SUBSCRIPTION $RESOURCE_ID_VNET1 $RESOURCE_ID_VNET2 $AADOBJECTID_GROUP_CLUSTERADMIN $K8S_RBAC_AAD_PROFILE_TENANTID $AKS_ENDUSER_NAME $AKS_ENDUSER_PASSWORD $RGNAME_FRONT_DOOR $SUBDOMAIN_BU0001A0042_03 $SUBDOMAIN_BU0001A0042_04

EOF




