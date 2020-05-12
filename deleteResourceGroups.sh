# This script might take about 30 minutes
# Please check the variables
RGLOCATION=eastus
RGNAME=rg-enterprise-networking-hubs
RGNAMESPOKES=rg-enterprise-networking-spokes
RGNAMECLUSTER=rg-cluster01
AKS_CLUSTER_NAME=aks-cunypcamxe7pa

echo deleting $RGNAMECLUSTER
az group delete -n $RGNAMECLUSTER --yes

echo deleting $RGNAME
az group delete -n $RGNAME --yes

echo deleting $RGNAMESPOKES
az group delete -n $RGNAMESPOKES --yes

echo deleting soft delete
az keyvault purge --name kv-${AKS_CLUSTER_NAME} --location ${RGLOCATION}