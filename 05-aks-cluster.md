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
   TARGET_VNET_RESOURCE_ID=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   ```

1. Deploy the cluster ARM template.

   **Option 1 - Deploy in the Azure Portal**

   Use the following deploy to Azure button to create the baseline cluster from the Azure Portal. You'll need to provide the parameter values as returned from prior steps in this guide.

   [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmspnp%2Freference-architectures%2Ffcp%2Faks-baseline%2Faks%2Fsecure-baseline%2Fcluster-stamp.json)

    **Option 2 - Deploy from the command line**

   ```bash
   # [This takes about 15 minutes.]
   az deployment group create --resource-group rg-bu0001a0008 --template-file cluster-stamp.json --parameters targetVnetResourceId=$TARGET_VNET_RESOURCE_ID k8sRbacAadProfileAdminGroupObjectID=$K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID k8sRbacAadProfileTenantId=$K8S_RBAC_AAD_PROFILE_TENANTID appGatewayListenerCertificate=$APP_GATEWAY_LISTENER_CERTIFICATE
   ```

   > Alteratively, you could have updated the [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) file and deployed as above, using `--parameters @azuredeploy.parameters.prod.json` instead of the individual key-value pairs.

    **Option 3 - Automated deploy using GitHub Actions (fork is required)**

    1. Create the Azure Credentials for the GitHub CD workflow

       ```bash
       # Create an Azure Service Principal
       az ad sp create-for-rbac --name "github-workflow-aks-cluster" --sdk-auth --skip-assignment > sp.json
       export APP_ID=$(grep -oP '(?<="clientId": ").*?[^\\](?=",)' sp.json)

       # Wait for it to get propagated
       until az ad sp show --id ${APP_ID} &> /dev/null ; do echo "Waiting for Azure AD propagation" && sleep 5; done

       # Assign the following Azure Role-Based Access Control (RBAC) built-in role for creating resource groups and place deployments at subscription level
       az role assignment create --assignee $APP_ID --role 'Contributor'

       # Assign the following Azure Role-Based Access Control (RBAC) built-in role  since granting RBAC access to other resources during the cluster creation will be required at subscription level (e.g. AKS-managed Internal Load Balancer, ACR, Managed Identities, etc.)
       az role assignment create --assignee $APP_ID --role 'User Access Administrator'
       ```

    1. Create `AZURE_CREDENTIALS` secret in your GitHub repository. For more
       information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository)

       > :bulb: use the content from `sp.json` file

       ```bash
       cat sp.json
       ```

    1. Create `APP_GATEWAY_LISTENER_CERTIFICATE_BASE64` secret in your GitHub repository. For more
       information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository)

       > :bulb:
       >  - use the env var value of `APP_GATEWAY_LISTENER_CERTIFICATE`
       >  - ideally fetch this secret from a platform-managed secret store such as [Azure KeyVault](https://github.com/marketplace/actions/azure-key-vault-get-secrets)

       ```bash
       echo $APP_GATEWAY_LISTENER_CERTIFICATE
       ```

    1. Copy the file GitHub workflow into the expected directory and configured it

       ```bash
       mkdir -p .github/workflows
       cat aks/secure-baseline/github-workflow/aks-deploy.yaml | \
           sed "s#<resource-group-location>#eastus2#g" | \
           sed "s#<resource-group-name>#rg-bu0001a0008#g" | \
           sed "s#<resource-group-localtion>#eastus2#g" | \
           sed "s#<geo-redundancy-location>#centralus#g" | \
           sed "s#<cluster-spoke-vnet-resource-id>#$TARGET_VNET_RESOURCE_ID#g" | \
           sed "s#<tenant-id-with-user-admin-permissions>#$K8S_RBAC_AAD_PROFILE_TENANTID#g" | \
           sed "s#<azure-ad-aks-admin-group-object-id>#$K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID#g" \
           > .github/workflows/aks-deploy.yaml
       ```

    1. Push the changes to your forked repo

       > :book: the GitOps team wants to automate their infrastructure deployments. In this case, they decided to use GitHub Actions among
       > other options such as Azure Pipelines, Jenkins and more. They are going to create a workflow for every AKS cluster instance
       > they have to take care of.

       ```bash
       git add .github/workflows/aks-deploy.yaml && git commit -m "setup GitHub CD workflow"
       git push origin HEAD:kick-off-workflow
       ```
       > :bulb: you might want to convert this GitHub workflow into a template since your organization might need to handle multiple AKS clusters.
       > For more information, please take a look at [Sharing Workflow Templates within your organization](https://docs.github.com/en/actions/configuring-and-managing-workflows/sharing-workflow-templates-within-your-organization)

    1. Navigate to your GitHub forked repository and open a PR against `master` using the recently pushed changes to the remote branch `kick-off-workflow`.

       > :book: the GitOps team configured the GitHub workflow to preview the changes that will happen when a PR is open. This will allow them to evaluate the changes before they get ironed. After the PR reviewers see how resources will change if the AKS cluster ARM template gets deployed, it is possible to merge or discard the pull request. If the decision made is merging, it will trigger a push event that will kick off the actual deployment process that consists on:
       >   - AKS cluster creation
       >   - Flux deployment

    1. Once the GitHub wokflow validation finished successfully, please procceed by merging this PR into `master`.

       > :book: the GitOps team monitors closely this workflow execution instance. In this oportunity it will
       > impact a critical pieace of infrastructure as well as the management. It could a new or existent AKS
       > cluster.

    1. :fast_forward: Flux is installed as part of the GitHub wokflow steps. Therefore, it is possible skip to [Workflow Prerequisites](./07-workload-prerequisites.md)

### Next step

:arrow_forward: [Place the cluster under GitOps management](./06-gitops.md)
