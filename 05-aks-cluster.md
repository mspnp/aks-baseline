# Deploy the AKS Cluster

Now that the [hub-spoke network is provisioned](./04-networking.md), the next step in the [AKS secure Baseline reference implementation](./) is deploying the AKS cluster and its adjacent Azure resources.

## Steps

1. Create the AKS cluster resource group.

   > :book: The app team working on behalf of business unit 0001 (BU001) is looking to create an AKS cluster of the app they are creating (Application ID: 0008). They have worked with the organization's networking team and have been provisioned a spoke network in which to lay their cluster and network-aware external resources into (such as Application Gateway). They took that information and added it to their [`cluster-stamp.json`](./cluster-stamp.json) and [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) files.
   >
   > They create this resource group to be the parent group for the application.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0008 --location eastus2
   ```

1. Get the AKS cluster spoke VNet resource ID.

   > :book: The app team will be deploying to a spoke VNet, that was already provisioned by the network team.

   ```bash
   RESOURCEID_VNET_CLUSTERSPOKE=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   ```

1. Deploy the cluster ARM template.  
  :exclamation: By default, this deployment will allow unrestricted access to your cluster's API Server.  You can limit access to the API Server to a set of well-known IP addresses (i.,e. a jump box subnet (connected to by Azure Bastion), build agents, or any other networks you'll administer the cluster from) by setting the `clusterAuthorizedIPRanges` parameter in all deployment options.  

    **Option 1 - Deploy from the command line**

   ```bash
   # [This takes about 15 minutes.]
   az deployment group create -g rg-bu0001a0008 -f cluster-stamp.json -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE} clusterAdminAadGroupObjectId=${AADOBJECTID_GROUP_CLUSTERADMIN} k8sControlPlaneAuthorizationTenantId=${TENANTID_K8SRBAC} appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE} aksIngressControllerCertificate=${AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64}
   ```

   > Alteratively, you could have updated the [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) file and deployed as above, using `-p "@azuredeploy.parameters.prod.json"` instead of providing the individual key-value pairs.

    **Option 2 - Automated deploy using GitHub Actions (fork is required)**

    1. Create the Azure Credentials for the GitHub CD workflow.

       ```bash
       # Create an Azure Service Principal
       az ad sp create-for-rbac --name "github-workflow-aks-cluster" --sdk-auth --skip-assignment > sp.json
       export APP_ID=$(grep -oP '(?<="clientId": ").*?[^\\](?=",)' sp.json)

       # Wait for propagation
       until az ad sp show --id ${APP_ID} &> /dev/null ; do echo "Waiting for Azure AD propagation" && sleep 5; done

       # Assign built-in Contributor RBAC role for creating resource groups and performing deployments at subscription level
       az role assignment create --assignee $APP_ID --role 'Contributor'

       # Assign built-in User Access Administrator RBAC role since granting RBAC access to other resources during the cluster creation will be required at subscription level (e.g. AKS-managed Internal Load Balancer, ACR, Managed Identities, etc.)
       az role assignment create --assignee $APP_ID --role 'User Access Administrator'
       ```

    1. Create `AZURE_CREDENTIALS` secret in your GitHub repository. For more
       information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository).

       > :bulb: Use the content from the `sp.json` file.

       ```bash
       cat sp.json
       ```

    1. Create `APP_GATEWAY_LISTENER_CERTIFICATE_BASE64` secret in your GitHub repository. For more
       information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository).

       > :bulb:
       >
       >  * Use the env var value of `APP_GATEWAY_LISTENER_CERTIFICATE`
       >  * Ideally fetching this secret from a platform-managed secret store such as [Azure KeyVault](https://github.com/marketplace/actions/azure-key-vault-get-secrets)

       ```bash
       echo $APP_GATEWAY_LISTENER_CERTIFICATE
       ```

    1. Create `AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64` secret in your GitHub repository. For more information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository).

       > :bulb:
       >
       >  * Use the env var value of `AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64`
       >  * Ideally fetching this secret from a platform-managed secret store such as [Azure Key Vault](https://github.com/marketplace/actions/azure-key-vault-get-secrets)

       ```bash
       echo $AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64
       ```

    1. Copy the GitHub workflow file into the expected directory and update the placeholders in it.

       ```bash
       mkdir -p .github/workflows
       cat github-workflow/aks-deploy.yaml | \
           sed "s#<resource-group-location>#eastus2#g" | \
           sed "s#<resource-group-name>#rg-bu0001a0008#g" | \
           sed "s#<geo-redundancy-location>#centralus#g" | \
           sed "s#<cluster-spoke-vnet-resource-id>#${RESOURCEID_VNET_CLUSTERSPOKE}#g" | \
           sed "s#<tenant-id-with-user-admin-permissions>#${TENANTID_K8SRBAC}#g" | \
           sed "s#<azure-ad-aks-admin-group-object-id>#${AADOBJECTID_GROUP_CLUSTERADMIN}#g" \
           > .github/workflows/aks-deploy.yaml
       ```

    1. Push the changes to your forked repo.

       > :book: The DevOps team wants to automate their infrastructure deployments. In this case, they decided to use GitHub Actions. They are going to create a workflow for every AKS cluster instance they have to take care of.

       ```bash
       git add .github/workflows/aks-deploy.yaml && git commit -m "setup GitHub CD workflow"
       git push origin HEAD:kick-off-workflow
       ```

       > :bulb: You might want to convert this GitHub workflow into a template since your organization or team might need to handle multiple AKS clusters. For more information, please take a look at [Sharing Workflow Templates within your organization](https://docs.github.com/actions/configuring-and-managing-workflows/sharing-workflow-templates-within-your-organization).

    1. Navigate to your GitHub forked repository and open a PR against `main` using the recently pushed changes to the remote branch `kick-off-workflow`.

       > :book: The DevOps team configured the GitHub Workflow to preview the changes that will happen when a PR is opened. This will allow them to evaluate the changes before they get deployed. After the PR reviewers see how resources will change if the AKS cluster ARM template gets deployed, it is possible to merge or discard the pull request. If the decision is made to merge, it will trigger a push event that will kick off the actual deployment process that consists of:
       >
       > * AKS cluster creation
       > * Flux deployment

    1. Once the GitHub Workflow validation finished successfully, please proceed by merging this PR into `main`.

       > :book: The DevOps team monitors this Workflow execution instance. In this instance it will impact a critical piece of infrastructure as well as the management. This flow works for both new or an existing AKS cluster.

    1. :fast_forward: The cluster is placed under GitOps managed as part of these GitHub Workflow steps. Therefore, you should proceed straight to [Workflow Prerequisites](./07-workload-prerequisites.md).

## Container registry note

:warning: To aid in ease of deployment of this cluster and your experimentation with workloads, Azure Policy and Azure Firewall are currently configured to allow your cluster to pull images from _public container registries_ such as Docker Hub. For a production system, you'll want to update Azure Policy parameter named `allowedContainerImagesRegex` in your `cluster-stamp.json` file to only list those container registries that you are willing to take a dependency on and what namespaces those policies apply to, and make Azure Firewall allowances for the same. This will protect your cluster from unapproved registries being used, which may prevent issues while trying to pull images from a registry which doesn't provide SLA guarantees for your deployment.

This deployment creates an SLA-backed Azure Container Registry for your cluster's needs. Your organization may have a central container registry for you to use, or your registry may be tied specifically to your application's infrastructure (as demonstrated in this implementation). **Only use container registries that satisfy the security and availability needs of your application.**

### Next step

:arrow_forward: [Place the cluster under GitOps management](./06-gitops.md)
