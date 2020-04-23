# This script might take about 30 minutes
# Please check the variables
RGNAME=rg-enterprise-networking-hubs
RGNAMESPOKES=rg-enterprise-networking-spokes
RGNAMECLUSTER=rg-cluster01

echo deleting $RGNAMECLUSTER
az group delete -n $RGNAMECLUSTER --yes

echo deleting $RGNAME
az group delete -n $RGNAME --yes

echo deleting $RGNAMESPOKES
az group delete -n $RGNAMESPOKES --yes