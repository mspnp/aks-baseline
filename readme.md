# Azure Kubernetes Services

This is a WIP.

Your azure user need to be able to assign RBAC permissions at the subscription resource groups level

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
