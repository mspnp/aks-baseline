# Azure Kubernetes Services

This is a WIP.

Your azure user need to be able to assign RBAC permissions at the subscription resource groups level

## Steps

- Please check the script variables at the beginning and then execute. The script is going to deploy all the template and Principal needed.  
  This script might take about 20 minutes

`deploy.sh`

### Clean up

- Please check the script variables at the beginning and then execute. Leave the Service Principal and App Registrations in Azure AD.

`deleteResourceGroups.sh`
