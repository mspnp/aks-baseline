# Azure Kubernetes Services

This is a WIP.

Your azure user need to be able to assign RBAC permissions at the subscription resource groups level

NOTE:
  Pay attention to https://docs.microsoft.com/en-us/azure/aks/managed-aad
  We are using a preview which need to be enable

   Caution
After you register a feature on a subscription, you can't currently unregister that feature. When you enable some preview features, defaults might be used for all AKS clusters created afterward in the subscription. Don't enable preview features on production subscriptions. Instead, use a separate subscription to test preview features and gather feedback.


## Steps

- Please check the script variables at the beginning and then execute.  
  The script is going to deploy all the templates and Principals needed.  
  This scripts might take about 30 minutes

First execute:  
`0-networking-stamp.sh`

Then take parameters from the previous execution, write into this script and execute:
`1-cluster-stamp.sh`
It is going to deploy the AKS Cluster

### Clean up

- Please check the script variables at the beginning and then execute. Leave the Service Principal and App Registrations in Azure AD.

`deleteResourceGroups.sh`
