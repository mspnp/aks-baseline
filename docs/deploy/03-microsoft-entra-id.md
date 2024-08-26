# Prep for Microsoft Entra ID integration

In the prior step, you [generated the user-facing TLS certificate](./02-ca-certificates.md); now we'll prepare Microsoft Entra ID for Kubernetes role-based access control (RBAC). This will ensure you have a Microsoft Entra security group(s) and user(s) assigned for group-based Kubernetes control plane access.

## Expected results

Following these steps will result in a Microsoft Entra ID configuration that will be used for Kubernetes control plane (Cluster API) authorization.

| Object                             | Purpose                                                 |
|------------------------------------|---------------------------------------------------------|
| A Cluster Admin Security Group     | Will be mapped to `cluster-admin` Kubernetes role.      |
| A Cluster Admin User               | Represents at least one break-glass cluster admin user. |
| Cluster Admin Group Membership     | Association between the cluster admin user(s) and the cluster admin security group. |
| A Namespace Reader Security Group  | Represents users that will have read-only access to a specific namespace in the cluster. |
| *Additional Security Groups*       | *Optional.* A security group (and its memberships) for the other built-in and custom Kubernetes roles you plan on using. |

This does not configure anything related to workload identity. This configuration is exclusively to set up RBAC access to perform cluster management.

## Steps

> :book: The Contoso Bicycle Microsoft Entra ID team requires all admin access to AKS clusters be security-group-based. This applies to the new AKS cluster that is being built for Application ID a0008 under the BU0001 business unit. Kubernetes RBAC will be Microsoft Entry ID-backed and access granted based on users' Microsoft Entra group memberships.

1. Query and save your Azure subscription's tenant ID.

   ```bash
   export TENANTID_AZURERBAC_AKS_BASELINE=$(az account show --query tenantId -o tsv)
   echo TENANTID_AZURERBAC_AKS_BASELINE: $TENANTID_AZURERBAC_AKS_BASELINE
   ```

1. Playing the role as the Contoso Bicycle Microsoft Entra ID team, login into the tenant where Kubernetes Cluster API authorization will be associated with.

   > :bulb: Skip the `az login` command if you plan to use your current user account's Microsoft Entra ID tenant for Kubernetes authorization. *Using the same tenant is common.*

   ```bash
   az login -t <Replace-With-ClusterApi-AzureAD-TenantId> --allow-no-subscriptions
   export TENANTID_K8SRBAC_AKS_BASELINE=$(az account show --query tenantId -o tsv)
   echo TENANTID_K8SRBAC_AKS_BASELINE: $TENANTID_K8SRBAC_AKS_BASELINE
   ```

1. Create/identify the Microsoft Entra security group that is going to map to the [Kubernetes Cluster Admin](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) role `cluster-admin`.

   If you already have a security group that is appropriate for your cluster's admin service accounts, use that group and don't create a new one. If using your own group or your Microsoft Entra ID administrator created one for you to use; you will need to update the group name and ID throughout the reference implementation.

   ```bash
   export MEIDOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE=[Paste your existing cluster admin group Object ID here.]
   echo MEIDOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE: $MEIDOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE
   ```

   If you want to create a new one instead, you can use the following code:

   ```bash
   export MEIDOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE=$(az ad group create --display-name 'cluster-admins-bu0001a000800' --mail-nickname 'cluster-admins-bu0001a000800' --description "Principals in this group are cluster admins in the bu0001a000800 cluster." --query id -o tsv)
   echo MEIDOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE: $MEIDOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE
   ```

   This Microsoft Entra group object ID will be used later while creating the cluster. This way, once the cluster gets deployed the new group will get the proper Cluster Role bindings in Kubernetes.

1. Create a "break-glass" cluster administrator user for your AKS cluster.

   > :book: The organization knows the value of having a break-glass admin user for their critical infrastructure. The workload team requests a cluster admin user and Microsoft Entra ID Admin team proceeds with the creation of the user in Microsoft Entra ID.

   You should skip this step, if the group identified in the former step already has a cluster admin assigned as member.

   ```bash
   TENANTDOMAIN_K8SRBAC=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
   MEIDOBJECTNAME_USER_CLUSTERADMIN=bu0001a000800-admin
   MEIDOBJECTID_USER_CLUSTERADMIN=$(az ad user create --display-name=${MEIDOBJECTNAME_USER_CLUSTERADMIN} --user-principal-name ${MEIDOBJECTNAME_USER_CLUSTERADMIN}@${TENANTDOMAIN_K8SRBAC} --force-change-password-next-sign-in --password ChangeMebu0001a0008AdminChangeMe --query id -o tsv)
   echo TENANTDOMAIN_K8SRBAC: $TENANTDOMAIN_K8SRBAC
   echo MEIDOBJECTNAME_USER_CLUSTERADMIN: $MEIDOBJECTNAME_USER_CLUSTERADMIN
   echo MEIDOBJECTID_USER_CLUSTERADMIN: $MEIDOBJECTID_USER_CLUSTERADMIN
   ```

1. Add the cluster admin user(s) to the cluster admin security group.

   > :book: The recently created break-glass admin user is added to the Kubernetes Cluster Admin group from Microsoft Entra ID. After this step the Microsoft Entra ID Admin team will have finished the workload team's request.

   You should skip this step, if the group identified in the former step already has a cluster admin assigned as member.

   ```bash
   az ad group member add -g $MEIDOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE --member-id $MEIDOBJECTID_USER_CLUSTERADMIN
   ```

1. Create/identify the Microsoft Entra security group that is going to be a namespace reader. *Optional*

   ```bash
   export MEIDOBJECTID_GROUP_A0008_READER_AKS_BASELINE=$(az ad group create --display-name 'cluster-ns-a0008-readers-bu0001a000800' --mail-nickname 'cluster-ns-a0008-readers-bu0001a000800' --description "Principals in this group are readers of namespace a0008 in the bu0001a000800 cluster." --query id -o tsv)
   echo MEIDOBJECTID_GROUP_A0008_READER_AKS_BASELINE: $MEIDOBJECTID_GROUP_A0008_READER_AKS_BASELINE
   ```

## Kubernetes RBAC backing store

AKS supports backing Kubernetes with Microsoft Entra ID in two different ways: Azure RBAC and direct Kubernetes RBAC management.

The preferred approach is to use Azure RBAC. This approach requires that you use the same Microsoft Entra ID tenant for both backing your Azure resources as well as your Kubernetes RBAC. When you this this approach, you manage your role-based access control by using Azure RBAC and you don't configure access control in the cluster.

However, in some situations, you might need to use two different Microsoft Entra ID tenants. For example, when you walk through this reference architecture, you may have had no choice but to associate the cluster with another tenant because of the elevated permissions necessary in Microsoft Entra ID to manage groups and users. In these situations, you can instead create direct associations between Microsoft Entra ID and Kubernetes `ClusterRoleBindings`/`RoleBindings` objects within the cluster. This approach is possible whether the Microsoft Entra ID tenant you wish to use to back your Kubernetes RBAC is the same or different than the tenant that backs your Azure resources.

Both approaches use integrated authentication between Microsoft Entra ID and AKS. The Azure RBAC approach simply elevates this control to Azure RBAC instead of direct YAML-based management within the cluster, and so the Azure RBAC approach usually aligns better with many organizations' governance strategy.

When you take this baseline architecture to production, be sure you're using Azure RBAC as your Kubernetes RBAC backing store if you can.

### Azure RBAC *[Preferred]*

If you are using a single tenant for this walk-through, the cluster deployment step later will take care of the necessary role assignments for the groups created above. In the preceding steps, you created the Microsoft Entra security group `cluster-ns-a0008-readers-bu0001a000800`. That group is going to be a namespace reader for the Kubernetes namespace `a0008`. The Microsoft Entra security group `cluster-admins-bu0001a000800` is going to contain cluster admins. Those group object IDs will be associated with the 'Azure Kubernetes Service RBAC Reader' and 'Azure Kubernetes Service RBAC Cluster Admin' RBAC roles respectively, scoped to their proper level within the cluster.

It's a good practice to use Azure RBAC as your authorization approach because it allows for the unified management and access control across Azure resources, AKS, and Kubernetes resources. At the time of this writing there are four [built-in Azure RBAC roles](https://learn.microsoft.com/azure/aks/manage-azure-rbac#create-role-assignments-for-users-to-access-cluster) that represent typical cluster access patterns.

### Direct Kubernetes RBAC management *[Alternative]*

You might not be able to use Azure RBAC as your Kubernetes RBAC authorization mechanism. This situation can happen because you have multiple Microsoft Entra ID tenants, or for another business justification. In this situation, you can manage your cluster's RBAC assignments through direct `ClusterRoleBinding`/`RoleBinding` associations. This method is also useful when the four Azure RBAC roles are not granular enough for your desired permission model.

1. Set up additional Kubernetes RBAC associations. *Optional, fork required.*

   > :book:  The team knows there will be more than just cluster admins that need group-managed access to the cluster. Out of the box, Kubernetes has other roles like *admin*, *edit*, and *view* which can also be mapped to Microsoft Entra groups for use both at namespace and at the cluster level. Likewise, custom roles can be created which need to be mapped to Microsoft Entra groups.

   In the [`cluster-rbac.yaml` file](../../cluster-manifests/cluster-rbac.yaml) and the various namespaced [`rbac.yaml files`](../../cluster-manifests/cluster-baseline-settings/rbac.yaml), you can uncomment the parts that you need, and replace the `<replace-with-a-microsoft-entra-group-object-id...>` placeholders with corresponding new or existing Microsoft Entra groups that map to their purpose for this cluster or namespace. **You do not need to perform this action for this walkthrough**; they are only here for your reference.

### Save your work in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to aks_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source aks_baseline.env
```

### Next step

:arrow_forward: [Deploy the hub-spoke network topology](./04-networking.md)
