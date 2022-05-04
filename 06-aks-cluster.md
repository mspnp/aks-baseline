# Deploy the AKS Cluster

Now that your [ACR instance is deployed and ready to support cluster bootstrapping](./05-bootstrap-prep.md), the next step in the [AKS baseline reference implementation](./) is deploying the AKS cluster and its remaining adjacent Azure resources.

## Steps

1. Indicate your bootstrapping repo.

   > If you cloned this repo, then the value will be the original mspnp GitHub organization's repo, which will mean that your cluster will be bootstraped using public container images. If instead you forked this repo, then the GitOps repo will be your own repo, and your cluster will be bootstrapped using container images references based on the values in your repo's manifest files. On the prior instruction page you had the oppertunity to update those manifests to use your ACR instance. For guidance on using a private bootstrapping repo, see [Private bootstrapping repository](./cluster-manifests/README.md#private-bootstrapping-repository).

   ```bash
   GITOPS_REPOURL=$(git config --get remote.origin.url)
   echo GITOPS_REPOURL: $GITOPS_REPOURL

   GITOPS_CURRENT_BRANCH_NAME=$(git branch --show-current)
   echo GITOPS_CURRENT_BRANCH_NAME: $GITOPS_CURRENT_BRANCH_NAME
   ```

1. Deploy the cluster ARM template.
  :exclamation: By default, this deployment will allow unrestricted access to your cluster's API Server. You can limit access to the API Server to a set of well-known IP addresses (i.,e. a jump box subnet (connected to by Azure Bastion), build agents, or any other networks you'll administer the cluster from) by setting the `clusterAuthorizedIPRanges` parameter in all deployment options. This setting will also impact traffic originating from within the cluster trying to use the API server, so you will also need to include _all_ of the public IPs used by your egress Azure Firewall. For more information, see [Secure access to the API server using authorized IP address ranges](https://docs.microsoft.com/azure/aks/api-server-authorized-ip-ranges#create-an-aks-cluster-with-api-server-authorized-ip-ranges-enabled).

    **Option 1 - Deploy from the command line**

   ```bash
   # [This takes about 18 minutes.]
   az deployment group create -g rg-bu0001a0008 -f cluster-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE} clusterAdminAadGroupObjectId=${AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE} a0008NamespaceReaderAadGroupObjectId=${AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE} k8sControlPlaneAuthorizationTenantId=${TENANTID_K8SRBAC_AKS_BASELINE} appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_AKS_BASELINE} aksIngressControllerCertificate=${AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64_AKS_BASELINE} domainName=${DOMAIN_NAME_AKS_BASELINE} gitOpsBootstrappingRepoHttpsUrl=${GITOPS_REPOURL} gitOpsBootstrappingRepoBranch=${GITOPS_CURRENT_BRANCH_NAME} location=eastus2
   ```

   > Alteratively, you could have updated the [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) file and deployed as above, using `-p "@azuredeploy.parameters.prod.json"` instead of providing the individual key-value pairs.

    **Option 2 - Automated deploy using GitHub Actions (fork is required)**

    1. Create the Azure Credentials for the GitHub CD workflow.

       ```bash
       # Create an Azure Service Principal
       #
       # This command will generate a sp.json file in the format expected by GitHub Actions for Azure.
       # This is accomplished by using the deprecated --sdk-auth flag. For alternatives, including using
       # Federated Identity, see https://github.com/Azure/login#configure-deployment-credentials.
       az ad sp create-for-rbac --name "github-workflow-aks-cluster" --sdk-auth --skip-assignment > sp.json
       export APP_ID=$(grep -oP '(?<="clientId": ").*?[^\\](?=",)' sp.json)
       echo APP_ID: $APP_ID

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
       echo $APP_GATEWAY_LISTENER_CERTIFICATE_AKS_BASELINE
       ```

    1. Create `AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64` secret in your GitHub repository. For more information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository).

       > :bulb:
       >
       >  * Use the env var value of `AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64`
       >  * Ideally fetching this secret from a platform-managed secret store such as [Azure Key Vault](https://github.com/marketplace/actions/azure-key-vault-get-secrets)

       ```bash
       echo $AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64_AKS_BASELINE
       ```

    1. Copy the GitHub workflow file into the expected directory and update the placeholders in it.

       ```bash
       mkdir -p .github/workflows
       cat github-workflow/aks-deploy.yaml | \
           sed "s#<resource-group-location>#eastus2#g" | \
           sed "s#<resource-group-name>#rg-bu0001a0008#g" | \
           sed "s#<geo-redundancy-location>#centralus#g" | \
           sed "s#<cluster-spoke-vnet-resource-id>#${RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE}#g" | \
           sed "s#<tenant-id-with-user-admin-permissions>#${TENANTID_K8SRBAC_AKS_BASELINE}#g" | \
           sed "s#<azure-ad-aks-admin-group-object-id>#${AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE}#g" | \
           sed "s#<azure-ad-aks-a0008-group-object-id>#${AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE}#g" | \
           sed "s#<domain-name>#${DOMAIN_NAME_AKS_BASELINE}#g" | \
           sed "s#<bootstrapping-repo-https-url>#${GITOPS_REPOURL}#g" \
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

       > :book: The DevOps team configured the GitHub Workflow to preview the changes that will happen when a PR is opened. This will allow them to evaluate the changes before they get deployed. After the PR reviewers see how resources will change if the AKS cluster ARM template gets deployed, it is possible to merge or discard the pull request. If the decision is made to merge, it will trigger a push event that will kick off the actual deployment process.

    1. Once the GitHub Workflow validation finished successfully, please proceed by merging this PR into `main`.

       > :book: The DevOps team monitors this Workflow execution instance. In this instance it will impact a critical piece of infrastructure as well as the management. This flow works for both new or an existing AKS cluster.

## Container registry note

:warning: To aid in ease of deployment of this cluster and your experimentation with workloads, Azure Policy and Azure Firewall are currently configured to allow your cluster to pull images from _public container registries_ such as Docker Hub. For a production system, you'll want to update Azure Policy parameter named `allowedContainerImagesRegex` in your `cluster-stamp.bicep` file to only list those container registries that you are willing to take a dependency on and what namespaces those policies apply to, and make Azure Firewall allowances for the same. This will protect your cluster from unapproved registries being used, which may prevent issues while trying to pull images from a registry which doesn't provide SLA guarantees for your deployment.

This deployment creates an SLA-backed Azure Container Registry for your cluster's needs. Your organization may have a central container registry for you to use, or your registry may be tied specifically to your application's infrastructure (as demonstrated in this implementation). **Only use container registries that satisfy the security and availability needs of your application.**

## Application Gateway placement

Azure Application Gateway, for this reference implementation, is placed in the same virtual network as the cluster nodes (isolated by subnets and related NSGs). This facilitates direct network line-of-sight from Application Gateway to the cluster's private load balancer and still allows for strong network boundary control. More importantly, this aligns with cluster operator team owning the point of ingress. Some organizations may instead leverage a perimeter network in which Application Gateway is managed centrally which resides in an entirely separated virtual network. That topology is also fine, but you'll need to ensure there is secure and limited routing between that perimeter network and your internal private load balancer for your cluster. Also, there will be additional coordination necessary between the cluster/workload operators and the team owning the Application Gateway.

### Next step

:arrow_forward: [Validate your cluster is bootstrapped](./07-bootstrap-validation.md)
