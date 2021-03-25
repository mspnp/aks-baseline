# Prep for Azure Active Directory Integration

Now that you have the [prerequisites](./01-prerequisites.md) met, follow the steps below to prepare Azure AD for Kubernetes role-based access control (RBAC). This will ensure you have an Azure AD security group(s) and user(s) assigned for group-based Kubernetes control plane access.

## Expected results

Following the steps below you will result in an Azure AD configuration that will be used for Kubernetes control plane (Cluster API) authorization.

| Object                             | Purpose                                                                                                                  |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| A Cluster Admin User               | Represents at least one break-glass cluster admin user.                                                                  |
| Two Cluster Admin Security Groups  | Will be mapped to `cluster-admin` Kubernetes role.                                                                       |
| Two Cluster Admin Group Membership | Association between the Cluster Admin User(s) and the two Cluster Admin Security Groups.                                 |

## Steps

> :book: The Contoso Bicycle Azure AD team requires all admin access to AKS clusters be security-group based. This applies to the two AKS clusters that are being created for Application ID a0042 under the BU001 business unit. Kubernetes RBAC will be AAD-backed and access granted based on a user's identity or directory group membership.

1. Create a single "break-glass" cluster administrator user for your AKS clusters, and add to both cluster admin security groups being created that are going to map to the [Kubernetes Cluster Admin](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) role `cluster-admin`.

   :book: The app team requested a single admin user that needs to have access in both clusters. The Azure AD Admin team create two different groups, one per cluster to home the new admin.

   ```bash
   # create a single admin for both clusters
   TENANTDOMAIN_K8SRBAC=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
   AADOBJECTNAME_USER_CLUSTERADMIN=bu0001a0042-admin
   AADOBJECTID_USER_CLUSTERADMIN=$(az ad user create --display-name=${AADOBJECTNAME_USER_CLUSTERADMIN} --user-principal-name ${AADOBJECTNAME_USER_CLUSTERADMIN}@${TENANTDOMAIN_K8SRBAC} --force-change-password-next-login --password ChangeMebu0001a0042AdminChangeMe --query objectId -o tsv)

   # create the admin groups
   AADOBJECTNAME_GROUP_CLUSTERADMIN_BU0001A004203=cluster-admins-bu0001a0042-03
   AADOBJECTNAME_GROUP_CLUSTERADMIN_BU0001A004204=cluster-admins-bu0001a0042-04
   AADOBJECTID_GROUP_CLUSTERADMIN_BU0001A004203=$(az ad group create --display-name $AADOBJECTNAME_GROUP_CLUSTERADMIN_BU0001A004203 --mail-nickname $AADOBJECTNAME_GROUP_CLUSTERADMIN_BU0001A004203 --description "Principals in this group are cluster admins in the bu0001a004203 cluster." --query objectId -o tsv)
   AADOBJECTID_GROUP_CLUSTERADMIN_BU0001A004204=$(az ad group create --display-name $AADOBJECTNAME_GROUP_CLUSTERADMIN_BU0001A004204 --mail-nickname $AADOBJECTNAME_GROUP_CLUSTERADMIN_BU0001A004204 --description "Principals in this group are cluster admins in the bu0001a004204 cluster." --query objectId -o tsv)

   # assign the admin as new member in both groups
   az ad group member add -g $AADOBJECTID_GROUP_CLUSTERADMIN_BU0001A004203 --member-id $AADOBJECTID_USER_CLUSTERADMIN
   az ad group member add -g $AADOBJECTID_GROUP_CLUSTERADMIN_BU0001A004204 --member-id $AADOBJECTID_USER_CLUSTERADMIN
   ```

   :bulb: For a better security segregation your organization might require to create multiple admins. This reference implementation creates a single one for the sake of simplicity. The group object ID will be used later while creating the different clusters. This way, once the clusters gets deployed the new group will get the proper Cluster Role bindings in Kubernetes. For more information, please refer to our [AKS Baseline](https://github.com/mspnp/aks-secure-baseline).

### Next step

:arrow_forward: [Deploy the hub-spoke network topology](./03-networking.md)
