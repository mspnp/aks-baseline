# Azure Kubernetes Services

This is a WIP.

Your azure user need to be able to assing permission on the subcription

## Steps

- Set Tenant Guid in the script and execute

`create-azure-ad-registrations.sh`

- Take the previous script's output and set the parameters for the next one and execute

`deploy.sh`

### Clean up

- Leave the Service Principal and App Registrations in Azure AD
- Delete the cluster resource group contents
- Delete the spoke resource group contents
- Delete the hub resource group contents
