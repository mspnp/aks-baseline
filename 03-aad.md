# Prep for Azure Active Directory Integration

In the prior step, you [generated the user-facing TLS certificate](./02-ca-certificates.md); now we'll prepare Azure AD for Kubernetes role-based access control (RBAC). This will ensure you have an Azure AD security group(s) and user(s) assigned for group-based Kubernetes control plane access.

## Expected results

Following the steps below you will result in an Azure AD configuration that will be used for Kubernetes control plane (Cluster API) authorization.

| Object                         | Purpose                                                 |
|--------------------------------|---------------------------------------------------------|
| A Cluster Admin Security Group | Will be mapped to `cluster-admin` Kubernetes role.      |
| A Cluster Admin User           | Represents at least one break-glass cluster admin user. |
| Cluster Admin Group Membership | Association between the Cluster Admin User(s) and the Cluster Admin Security Group. |
| _Additional Security Groups_   | _Optional._ A security group (and its memberships) for the other built-in and custom Kubernetes roles you plan on using. |

## Steps

> :book: The Contoso Bicycle Azure AD team requires all admin access to AKS clusters be security-group based. This applies to the new AKS cluster that is being built for Application ID a0008 under the BU001 business unit. Kubernetes RBAC will be AAD-backed and access granted based on a user's AAD group membership.

1. Query and save your Azure subscription's tenant id.

   ```bash
   TENANTID_AZURERBAC=$(az account show --query tenantId -o tsv)
   ```

1. Playing the role as the Contoso Bicycle Azure AD team, login into the tenant where Kubernetes Cluster API authorization will be associated with.

   ```bash
   az login -t <Replace-With-ClusterApi-AzureAD-TenantId> --allow-no-subscriptions
   TENANTID_K8SRBAC=$(az account show --query tenantId -o tsv)
   ```

1. Create/identify the Azure AD security group that is going to map to the [Kubernetes Cluster Admin](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) role `cluster-admin`.

   If you already have a security group that is appropriate for your cluster's admin service accounts, use that group and skip this step. If using your own group or your Azure AD administrator created one for you to use; you will need to update the group name and ID throughout the reference implementation.

   ```bash
   export AADOBJECTID_GROUP_CLUSTERADMIN=$(az ad group create --display-name 'cluster-admins-bu0001a000800' --mail-nickname 'cluster-admins-bu0001a000800' --description "Principals in this group are cluster admins in the bu0001a000800 cluster." --query objectId -o tsv)
   ```

   This Azure AD group object ID will be used later while creating the cluster. This way, once the cluster gets deployed the new group will get the proper Cluster Role bindings in Kubernetes.

1. Create a "break-glass" cluster administrator user for your AKS cluster.

   > :book: The organization knows the value of having a break-glass admin user for their critical infrastructure. The app team requests a cluster admin user and Azure AD Admin team proceeds with the creation of the user in Azure AD.

   ```bash
   export TENANTDOMAIN_K8SRBAC=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
   export AADOBJECTNAME_USER_CLUSTERADMIN=bu0001a000800-admin
   export AADOBJECTID_USER_CLUSTERADMIN=$(az ad user create --display-name=${AADOBJECTNAME_USER_CLUSTERADMIN} --user-principal-name ${AADOBJECTNAME_USER_CLUSTERADMIN}@${TENANTDOMAIN_K8SRBAC} --force-change-password-next-login --password ChangeMebu0001a0008AdminChangeMe --query objectId -o tsv)
   ```

1. Add the cluster admin user(s) to the cluster admin security group.

   > :book: The recently created break-glass admin user is added to the Kubernetes Cluster Admin group from Azure AD. After this step the Azure AD Admin team will have finished the app team's request.

   ```bash
   az ad group member add -g $AADOBJECTID_GROUP_CLUSTERADMIN --member-id $AADOBJECTID_USER_CLUSTERADMIN
   ```

1. Create/identify the Azure AD security group that is going to be a namespace reader.

   ```bash
   export AADOBJECTID_GROUP_A0005_READER=$(az ad group create --display-name 'cluster-ns-a0005-readers-bu0001a000800' --mail-nickname 'cluster-ns-a0005-readers-bu0001a000800' --description "Principals in this group are readers of namespace a0005 in the bu0001a000800 cluster." --query objectId -o tsv)
   ```

## Kubernetes RBAC backing store

In the prerequisites step you created a new tenant if you were not part of the User Administrator group in the tenant associated to your Azure subscription, if that is the case you will still leverage integrated authentication between Azure Active Directory (Azure AD) and AKS. When enabled, this integration allows customers to use Azure AD users, groups, or service principals as subjects in Kubernetes RBAC. This feature frees you from having to separately manage user identities and credentials for Kubernetes. However, you still have to set up and manage Azure.

On the other hand, if you are using a single tenant (the one associated with your Azure subscription) and you have enough privileges to create the AKS admin Active Directory Security Group, the cluster deployment step will take care of the Azure AD group association by making use of Azure RBAC for Kubernetes Authorization; this approach allows for the unified management and access control across Azure Resources, AKS, and Kubernetes resources.

1. Set up groups to map into other Kubernetes Roles. _Optional, fork required._

   > :book:  Follow this step if you forked the repository and you have two separate tenants, since in that case you are making use of integrated authentication between Azure Active Directory (Azure AD) and AKS.
   The team knows there will be more than just cluster admins that need group-managed access to the cluster. Out of the box, Kubernetes has other roles like _admin_, _edit_, and _view_ which can also be mapped to Azure AD Groups for use both at namespace and at the cluster level.

   In the [`cluster-rbac.yaml` file](./cluster-manifests/cluster-rbac.yaml) and the various namespaced [`rbac.yaml files`](./cluster-manifests/cluster-baseline-settings/rbac.yaml), you can uncomment what you wish and replace the `<replace-with-an-aad-group-object-id...>` placeholders with corresponding new or existing AD groups that map to their purpose for this cluster or namespace. You do not need to perform this action for this walk through; they are only here for your reference.

   :bulb: If your tenants are the same, you will allow Azure RBAC to be the backing store for your Kubernetes RBAC, so you will transparently make these group associations to [Azure RBAC roles](https://docs.microsoft.com/azure/aks/manage-azure-rbac) in the cluster deployment step. Above in the steps you created the Azure AD security group that is going to be a namespace reader, that Group ID will be associated with the 'Azure Kubernetes Service RBAC Reader' Azure RBAC built in role.

### Next step

:arrow_forward: [Deploy the hub-spoke network topology](./04-networking.md)
