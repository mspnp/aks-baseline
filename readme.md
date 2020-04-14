# Azure Kubernetes Services

This is a WIP.

Your azure user need to be able to assing permission on the subcription

## Steps

- Please check the script variables at the beginning and then execute. The script is going to deploy all the template and Principal needed.

`deploy.sh`

### Clean up

- Leave the Service Principal and App Registrations in Azure AD
- Delete the cluster resource group contents
- Delete the spoke resource group contents
- Delete the hub resource group contents
