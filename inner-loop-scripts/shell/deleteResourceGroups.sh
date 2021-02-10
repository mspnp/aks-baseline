#!/usr/bin/env bash

set -e

# This script might take about 30 minutes
# Please check the variables
RGLOCATION=$1
RGNAMEHUB=$2
RGNAMESPOKES=$3
RGNAMECLUSTER_BU0001A0042_03=$4
RGNAMECLUSTER_BU0001A0042_04=$5
AKS_CLUSTER_NAME_BU0001A0042_03=$6
AKS_CLUSTER_NAME_BU0001A0042_04=$7
MAIN_SUBSCRIPTION=$8
RGNAME_FRONT_DOOR=$9

__usage="
    [-c RGNAMECLUSTER_BU0001A0042_03]
    [-d RGNAMECLUSTER_BU0001A0042_04]
    [-h RGNAMEHUB]
    [-k AKS_CLUSTER_NAME_BU0001A0042_03]
    [-z AKS_CLUSTER_NAME_BU0001A0042_04]
    [-l LOCATION]
    [-p RGNAMESPOKES]
    [-s MAIN_SUBSCRIPTION]
    [-f RGNAME_FRONT_DOOR]
"

usage() {
    echo "usage: ${0##*/}"
    echo "${__usage/[[:space:]]/}"
    exit 1
}

while getopts "c:d:h:l:p:k:z:s:f:" opt; do
    case $opt in
    c)  RGNAMECLUSTER_BU0001A0042_03="${OPTARG}";;
    d)  RGNAMECLUSTER_BU0001A0042_04="${OPTARG}";;
    h)  RGNAMEHUB="${OPTARG}";;
    l)  LOCATION="${OPTARG}";;
    p)  RGNAMESPOKES="${OPTARG}";;
    k)  AKS_CLUSTER_NAME_BU0001A0042_03="${OPTARG}";;
    z)  AKS_CLUSTER_NAME_BU0001A0042_04="${OPTARG}";;
    s)  MAIN_SUBSCRIPTION="${OPTARG}";;
    f)  RGNAME_FRONT_DOOR="${OPTARG}";;
    *)  usage;;
    esac
done
shift $(( $OPTIND - 1 ))

if [ $OPTIND = 1 ]; then
    usage
    exit 0
fi

az login
az account set -s $MAIN_SUBSCRIPTION

echo deleting $RGNAME_FRONT_DOOR
az group delete -n $RGNAME_FRONT_DOOR --yes

echo deleting $RGNAMECLUSTER_BU0001A0042_03
az group delete -n $RGNAMECLUSTER_BU0001A0042_03 --yes

echo deleting $RGNAMECLUSTER_BU0001A0042_04
az group delete -n $RGNAMECLUSTER_BU0001A0042_04 --yes

echo deleting $RGNAMESPOKES
az group delete -n $RGNAMESPOKES --yes

echo deleting $RGNAMEHUB
az group delete -n $RGNAMEHUB --yes

echo deleting key vault soft delete
az keyvault purge --name kv-${AKS_CLUSTER_NAME_BU0001A0042_03} --location ${LOCATION}

echo deleting key vault soft delete
az keyvault purge --name kv-${AKS_CLUSTER_NAME_BU0001A0042_04} --location ${LOCATION}

echo deleting azure policy assignments
for p in $(az policy assignment list --disable-scope-strict-match --query "[?resourceGroup=='${RGNAMECLUSTER_BU0001A0042_03}'].name" -o tsv); do az policy assignment delete --name ${p} --resource-group ${RGNAMECLUSTER_BU0001A0042_03}; done
for p in $(az policy assignment list --disable-scope-strict-match --query "[?resourceGroup=='${RGNAMECLUSTER_BU0001A0042_04}'].name" -o tsv); do az policy assignment delete --name ${p} --resource-group ${RGNAMECLUSTER_BU0001A0042_04}; done


#Remove the Azure Policy assignments scoped to the cluster's resource group. To identify those created by this implementation,
# look for ones that are prefixed with [your-cluster-name] .
