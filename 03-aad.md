# Prep for Azure Active Directory Integration

In the prior step, you [generated the user-facing TLS certificate](./02-ca-certificates.md); now we'll prepare Azure AD for Kubernetes role-based access control (RBAC). This will ensure you have an Azure AD security group(s) and user(s) assigned for group-based Kubernetes control plane access.

## Expected results

Following the steps below you will result in an Azure AD configuration that will be used for Kubernetes control plane (Cluster API) authorization.

| Object                             | Purpose                                                 |
|------------------------------------|---------------------------------------------------------|
| A Cluster Admin Security Group     | Will be mapped to `cluster-admin` Kubernetes role.      |
| A Cluster Admin User               | Represents at least one break-glass cluster admin user. |
| Cluster Admin Group Membership     | Association between the Cluster Admin User(s) and the Cluster Admin Security Group. |
| A Namespace Reader Security Group  | Represents users that will have read-only access to a specific namespace in the cluster. |
| _Additional Security Groups_       | _Optional._ A security group (and its memberships) for the other built-in and custom Kubernetes roles you plan on using. |

## Steps

> :book: The Contoso Bicycle Azure AD team requires all admin access to AKS clusters be security-group based. This applies to the new AKS cluster that is being built for Application ID a0008 under the BU0001 business unit. Kubernetes RBAC will be AAD-backed and access granted based on users' AAD group membership(s).

1. Query and save your Azure subscription's tenant id.

   ```bash
   export TENANTID_AZURERBAC_AKS_BASELINE=$(az account show --query tenantId -o tsv)
   echo TENANTID_AZURERBAC_AKS_BASELINE: $TENANTID_AZURERBAC_AKS_BASELINE
   ```

1. Playing the role as the Contoso Bicycle Azure AD team, login into the tenant where Kubernetes Cluster API authorization will be associated with.

   > :bulb: Skip the `az login` command if you plan to use your current user account's Azure AD tenant for Kubernetes authorization.

   ```bash
   az login -t <Replace-With-ClusterApi-AzureAD-TenantId> --allow-no-subscriptions
   export TENANTID_K8SRBAC_AKS_BASELINE=$(az account show --query tenantId -o tsv)
   echo TENANTID_K8SRBAC_AKS_BASELINE: $TENANTID_K8SRBAC_AKS_BASELINE
   ```

1. Create/identify the Azure AD security group that is going to map to the [Kubernetes Cluster Admin](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) role `cluster-admin`.

   If you already have a security group that is appropriate for your cluster's admin service accounts, use that group and don't create a new one. If using your own group or your Azure AD administrator created one for you to use; you will need to update the group name and ID throughout the reference implementation.
   ```bash
   export AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE=[Paste your existing cluster admin group Object ID here.]
   echo AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE: $AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE
   ```

   If you want to create a new one instead, you can use the following code:

   ```bash
   export AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE=$(az ad group create --display-name 'cluster-admins-bu0001a000800' --mail-nickname 'cluster-admins-bu0001a000800' --description "Principals in this group are cluster admins in the bu0001a000800 cluster." --query id -o tsv)
   echo AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE: $AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE
   ```

   This Azure AD group object ID will be used later while creating the cluster. This way, once the cluster gets deployed the new group will get the proper Cluster Role bindings in Kubernetes.

1. Create a "break-glass" cluster administrator user for your AKS cluster.

   > :book: The organization knows the value of having a break-glass admin user for their critical infrastructure. The app team requests a cluster admin user and Azure AD Admin team proceeds with the creation of the user in Azure AD.

   You should skip this step, if the group identified in the former step already has a cluster admin assigned as member.

   ```bash
   TENANTDOMAIN_K8SRBAC=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
   AADOBJECTNAME_USER_CLUSTERADMIN=bu0001a000800-admin
   AADOBJECTID_USER_CLUSTERADMIN=$(az ad user create --display-name=${AADOBJECTNAME_USER_CLUSTERADMIN} --user-principal-name ${AADOBJECTNAME_USER_CLUSTERADMIN}@${TENANTDOMAIN_K8SRBAC} --force-change-password-next-sign-in --password ChangeMebu0001a0008AdminChangeMe --query id -o tsv)
   echo TENANTDOMAIN_K8SRBAC: $TENANTDOMAIN_K8SRBAC
   echo AADOBJECTNAME_USER_CLUSTERADMIN: $AADOBJECTNAME_USER_CLUSTERADMIN
   echo AADOBJECTID_USER_CLUSTERADMIN: $AADOBJECTID_USER_CLUSTERADMIN
   ```

1. Add the cluster admin user(s) to the cluster admin security group.

   > :book: The recently created break-glass admin user is added to the Kubernetes Cluster Admin group from Azure AD. After this step the Azure AD Admin team will have finished the app team's request.

   You should skip this step, if the group identified in the former step already has a cluster admin assigned as member.

   ```bash
   az ad group member add -g $AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE --member-id $AADOBJECTID_USER_CLUSTERADMIN
   ```

1. Create/identify the Azure AD security group that is going to be a namespace reader. _Optional_

   ```bash
   export AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE=$(az ad group create --display-name 'cluster-ns-a0008-readers-bu0001a000800' --mail-nickname 'cluster-ns-a0008-readers-bu0001a000800' --description "Principals in this group are readers of namespace a0008 in the bu0001a000800 cluster." --query id -o tsv)
   echo AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE: $AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE
   ```

## Kubernetes RBAC backing store

AKS supports backing Kubernetes with Azure AD in two different modalities. One is direct association between Azure AD and Kubernetes `ClusterRoleBindings`/`RoleBindings` in the cluster. This is possible no matter if the Azure AD tenant you wish to use to back your Kubernetes RBAC is the same or different than the Tenant backing your Azure resources. If however the tenant that is backing your Azure resources (Azure RBAC source) is the same tenant you plan on using to back your Kubernetes RBAC, then instead you can add a layer of indirection between Azure AD and your cluster by using Azure RBAC instead of direct cluster `RoleBinding` manipulation. When performing this walk-through, you may have had no choice but to associate the cluster with another tenant (due to the elevated permissions necessary in Azure AD to manage groups and users); but when you take this to production be sure you're using Azure RBAC as your Kubernetes RBAC backing store if the tenants are the same. Both cases still leverage integrated authentication between Azure AD and AKS, Azure RBAC simply elevates this control to Azure RBAC instead of direct yaml-based management within the cluster which usually will align better with your organization's governance strategy.

### Azure RBAC _[Preferred]_

If you are using a single tenant for this walk-through, the cluster deployment step later will take care of the necessary role assignments for the groups created above. Specifically, in the above steps, you created the Azure AD security group `cluster-ns-a0008-readers-bu0001a000800` that is going to be a namespace reader in namespace `a0008` and the Azure AD security group `cluster-admins-bu0001a000800` is going to contain cluster admins. Those group Object IDs will be associated to the 'Azure Kubernetes Service RBAC Reader' and 'Azure Kubernetes Service RBAC Cluster Admin' RBAC role respectively, scoped to their proper level within the cluster.

Using Azure RBAC as your authorization approach is ultimately preferred as it allows for the unified management and access control across Azure Resources, AKS, and Kubernetes resources. At the time of this writing there are four [Azure RBAC roles](https://docs.microsoft.com/azure/aks/manage-azure-rbac#create-role-assignments-for-users-to-access-cluster) that represent typical cluster access patterns.

### Direct Kubernetes RBAC management _[Alternative]_

If you instead wish to not use Azure RBAC as your Kubernetes RBAC authorization mechanism, either due to the intentional use of disparate Azure AD tenants or another business justifications, you can then manage these RBAC assignments via direct `ClusterRoleBinding`/`RoleBinding` associations. This method is also useful when the four Azure RBAC roles are not granular enough for your desired permission model.

1. Set up additional Kubernetes RBAC associations. _Optional, fork required._

   > :book:  The team knows there will be more than just cluster admins that need group-managed access to the cluster. Out of the box, Kubernetes has other roles like _admin_, _edit_, and _view_ which can also be mapped to Azure AD Groups for use both at namespace and at the cluster level. Likewise custom roles can be created which need to be mapped to Azure AD Groups.

   In the [`cluster-rbac.yaml` file](./cluster-manifests/cluster-rbac.yaml) and the various namespaced [`rbac.yaml files`](./cluster-manifests/cluster-baseline-settings/rbac.yaml), you can uncomment what you wish and replace the `<replace-with-an-aad-group-object-id...>` placeholders with corresponding new or existing Azure AD groups that map to their purpose for this cluster or namespace. **You do not need to perform this action for this walkthrough**; they are only here for your reference.

### Save your work in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to aks_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source aks_baseline.env
```

### Next step

:arrow_forward: [Deploy the hub-spoke network topology](./04-networking.md)
