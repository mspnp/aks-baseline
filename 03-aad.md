# Prep for Azure Active Directory Integration

In the prior step, you [generated the user-facing TLS certificate](./02-ca-certificates.md), now we'll prepare for leveraging Azure AD for Kubernetes role-based access control (RBAC). This is the last of the cluster infrastructure prerequisites.

## Steps

> :book: The Contoso Bicycle Azure AD team requires all admin access to AKS clusters be security-group based. This applies to the new Secure AKS cluster that is being built for Application ID a0008 under the BU001 business unit. Kubernetes RBAC will be AAD-backed and access granted based on a user's identity or directory group membership.

1. Query and save your Azure subscription tenant id

   ```bash
   export TENANT_ID=$(az account show --query tenantId --output tsv)
   ```

1. Login into the tenant where you are a Azure AD User Administrator playing the role as the Contoso Bicycle Azure AD team

   ```bash
   az login --tenant <replace-with-tenant-id-with-user-admin-permissions> --allow-no-subscriptions
   export K8S_RBAC_AAD_PROFILE_TENANTID=$(az account show --query tenantId --output tsv)
   ```

1. Create the first the Azure AD group that is going to map the Kubernetes Cluster Role Admin. If you already have a security group that is appropriate for cluster admins, consider using that group and skipping this step. If using your own group, you will need to update group object names throughout the reference implementation.

   ```bash
   export K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID=$(az ad group create --display-name aad-to-bu0001a000800-cluster-admin --mail-nickname aad-to-bu0001a000800-cluster-admin --query objectId -o tsv)
   ```

1. Create a break-glass Cluster Admin user for your AKS cluster

   > :book: The organization knows the value of having a break-glass admin user for their critical infrastructure. The app team requests a cluster admin user and Azure AD Admin team proceeds with the creation of the user from Azure AD.

   ```bash
   export K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
   export AKS_ADMIN_OBJECTID=$(az ad user create --display-name=bu0001a0008-admin --user-principal-name bu0001a0008-admin@${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME} --force-change-password-next-login --password ChangeMebu0001a0008AdminChangeMe --query objectId -o tsv)
   ```

1. Add the new admin user to new security group so can be granted with the Kubernetes Cluster Admin role.

   > :book: The recently created break-glass admin user is added to the Kubernetes Cluster Admin group from Azure AD. After this step the Azure AD Admin team will have finished the app team's request and the outcome are:
   >
   > * the new app team's user admin credentials
   > * and the Azure AD group object ID
   >

   ```bash
   az ad group member add --group aad-to-bu0001a000800-cluster-admin --member-id $AKS_ADMIN_OBJECTID
   ```

   This object ID will be used later while creating the cluster. This way, once the cluster gets deployed the new group will get the proper Cluster Role bindings in Kubernetes.

1. Set up groups to map into other Kubernetes Roles. (Optional, fork required)

   > :book: The team knows there will be more than just cluster admins that need group-managed access to the cluster.  Out of the box, Kubernetes has other roles like _admin_, _edit_, and _view_ which can also be mapped to Azure AD Groups.

   In the [`user-facing-cluster-role-aad-group.yaml` file](./cluster-baseline-settings/user-facing-cluster-role-aad-group.yaml), you can replace the four `<replace-with-an-aad-group-object-id-for-this-cluster-role-binding>` placeholders with corresponding new or existing AD groups that map to their purpose for this cluster.

   :bulb: Alternatively, you can make these group associations to [Azure RBAC roles](https://docs.microsoft.com/azure/aks/manage-azure-rbac). At the time of this writing, this feature is still in _preview_, but will become the preferred way of mapping identities to Kubernetes RBAC roles.

### Next step

:arrow_forward: [Deploy the hub-spoke network topology](./04-networking.md)
