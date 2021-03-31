#!/usr/bin/env bash

set -e

# This script might take about 30 minutes
# Please check the variables
RGLOCATION=$1
RGNAMEHUB=$2
RGNAMESPOKES=$3
RGNAMECLUSTER=$4
AKS_CLUSTER_NAME=$5

__usage="
    [-c RGNAMECLUSTER]
    [-h RGNAMEHUB]
    [-k AKS_CLUSTER_NAME]
    [-l LOCATION]
    [-p RGNAMESPOKES]
"

usage() {
    echo "usage: ${0##*/}"
    echo "${__usage/[[:space:]]/}"
    exit 1
}

while getopts "c:h:l:p:k:" opt; do
    case $opt in
    c)  RGNAMECLUSTER="${OPTARG}";;
    h)  RGNAMEHUB="${OPTARG}";;
    l)  LOCATION="${OPTARG}";;
    p)  RGNAMESPOKES="${OPTARG}";;
    k)  AKS_CLUSTER_NAME="${OPTARG}";;
    *)  usage;;
    esac
done
shift $(( $OPTIND - 1 ))

if [ $OPTIND = 1 ]; then
    usage
    exit 0
fi

echo deleting $RGNAMECLUSTER
az group delete -n $RGNAMECLUSTER --yes

echo deleting $RGNAMESPOKES
az group delete -n $RGNAMESPOKES --yes

echo deleting $RGNAMEHUB
az group delete -n $RGNAMEHUB --yes

echo deleting key vault soft delete
az keyvault purge --name kv-${AKS_CLUSTER_NAME} --location ${LOCATION}

echo deleting azure policy assignments
for p in $(az policy assignment list --disable-scope-strict-match --query "[?resourceGroup=='${RGNAMECLUSTER}'].name" -o tsv); do az policy assignment delete --name ${p} --resource-group ${RGNAMECLUSTER}; done
