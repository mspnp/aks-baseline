# This script might take about 30 minutes
# Please check the variables
RGLOCATION=$1
RGNAMEHUB=$2
RGNAMESPOKES=$3
RGNAMECLUSTER=$4
AKS_CLUSTER_NAME=$5

echo deleting $RGNAMECLUSTER
az group delete -n $RGNAMECLUSTER --yes

echo deleting $RGNAMEHUB
az group delete -n $RGNAMEHUB --yes

echo deleting $RGNAMESPOKES
az group delete -n $RGNAMESPOKES --yes

echo deleting key vault soft delete
az keyvault purge --name kv-${AKS_CLUSTER_NAME} --location ${RGLOCATION}