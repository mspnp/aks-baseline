# Azure Active Directory Integration

Previously you have [acquired the Azure Application Gateway certificate](./02-ca-certificates),
now execute the following steps to start integrating AKS-managed Azure AD.

---
> The Contoso Bicycle Azure AD Admin and Security team requires all admin access to
> AKS clusters be security group based. This applies to the new Secure AKS cluster
> that is being built for Application ID: a0008 under the BU001 business unit.
> Kubernetes role-based access control (RBAC) will be AAD-backed and access granted
> based on a user's identity or directory group membership. AKS-managed Azure AD
> is the solution.

1. Query and save your Azure subscription tenant id

   ```bash
   export TENANT_ID=$(az account show --query tenantId --output tsv)
   ```

1. Login into the tenant where you are a User Administrator playing the role as the
   Contoso Bicycle user admin

   ```bash
   az login --tenant <tenant-id-with-user-admin-permissions> --allow-no-subscriptions
   export K8S_RBAC_AAD_PROFILE_TENANTID=$(az account show --query tenantId --output tsv)
   ```

1. Create first the Azure AD group that is going to map the Kubernetes Cluster Role Admin.

   ```bash
   K8S_RBAC_AAD_ADMIN_GROUP_OBJECTID=$(az ad group create --display-name add-to-bu0001a000800-cluster-admin --mail-nickname add-to-bu0001a000800-cluster-admin --query objectId -o tsv)
   ```

1. Create another Cluster Admin for your AKS cluster

   > Later the app team's admin member requested a Cluster Admin User. Therefore,
   > the Azure AD Admin team procceds with the creation of a new user from Azure AD.

   ```bash
   K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME=$(az ad signed-in-user show --query 'userPrincipalName' | cut -d '@' -f 2 | sed 's/\"//')
   AKS_ADMIN_OBJECTID=$(az ad user create --display-name=bu0001a0008-admin --user-principal-name bu0001a0008-admin@${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME} --force-change-password-next-login --password bu0001a0008Admin --query objectId -o tsv)
   ```

1. Add the user to group so it is granted with the Kubernetes Cluster Admin role

   > Then the recently created user is added to the Kubernetes Cluster Admin group from Azure AD.
   > After this step the Azure AD Admin team will have finished the app team's request and
   > the outcome are:
   > * the new app team's user admin credentials
   > * and the Azure AD group object ID
   > The `object ID` will be used later while creating the cluster as the final step for this integration.
   > This way, once the cluster gets deployed the new group will get the proper Cluster Role bindings

   ```bash
   az ad group member add --group add-to-bu0001a000800-cluster-admin --member-id $AKS_ADMIN_OBJECTID
   ```
---
Next Step: [Hub Spoke Network Topology](./04-networking.md)
