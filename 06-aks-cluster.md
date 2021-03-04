# Deploy the AKS Cluster

Now that the [cluster prequisites and shared Azure service instances are provisioned](./05-cluster-prerequisites.md), the next step in the [AKS secure Baseline reference implementation](./) is deploying the AKS clusters and its adjacent Azure resources.

## Steps

1.  Obtain shared services resource details

    ```bash
    LOGANALYTICSWORKSPACEID=$(az deployment group show -g rg-bu0001a0042-shared -n shared-svcs-stamp --query properties.outputs.logAnalyticsWorkspaceId.value -o tsv)
    CONTAINERREGISTRYID=$(az deployment group show -g rg-bu0001a0042-shared -n shared-svcs-stamp --query properties.outputs.containerRegistryId.value -o tsv)
    ACRPRIVATEDNSZONESID=$(az deployment group show -g rg-bu0001a0042-shared -n shared-svcs-stamp --query properties.outputs.acrPrivateDnsZonesId.value -o tsv)
    ```

1.  Get the corresponding AKS cluster spoke VNet resource IDs for the app team working on the application A0042.

    > :book: The app team will be deploying to a spoke VNet, that was already provisioned by the network team.

    ```bash
    RESOURCEID_VNET_BU0001A0042_03=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0042-03 --query properties.outputs.clusterVnetResourceId.value -o tsv)
    RESOURCEID_VNET_BU0001A0042_04=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0042-04 --query properties.outputs.clusterVnetResourceId.value -o tsv)
    ```

    **Automated deploy using GitHub Actions (fork is required)**

    1.  Create the Azure Credentials for the GitHub CD workflow.

        ```bash
        # Create an Azure Service Principal
        az ad sp create-for-rbac --name "github-workflow-aks-cluster" --sdk-auth --skip-assignment > sp.json
        APP_ID=$(grep -oP '(?<="clientId": ").*?[^\\](?=",)' sp.json)

        # Wait for propagation
        until az ad sp show --id ${APP_ID} &> /dev/null ; do echo "Waiting for Azure AD propagation" && sleep 5; done

        # Assign built-in Contributor RBAC role for creating resource groups and performing deployments at subscription level
        az role assignment create --assignee $APP_ID --role 'Contributor'

        # Assign built-in User Access Administrator RBAC role since granting RBAC access to other resources during the cluster creation will be required at subscription level (e.g. AKS-managed Internal Load Balancer, ACR, Managed Identities, etc.)
        az role assignment create --assignee $APP_ID --role 'User Access Administrator'
        ```

    1.  Create `AZURE_CREDENTIALS` secret in your GitHub repository. For more
        information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository).

        > :bulb: Use the content from the `sp.json` file.

        ```bash
        cat sp.json
        ```

    1.  Create `APP_GATEWAY_LISTENER_REGION1_CERTIFICATE_BASE64` and `APP_GATEWAY_LISTENER_REGION2_CERTIFICATE_BASE64` secret in your GitHub repository. For more
        information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository).

        > :bulb:
        >
        > - Use the env var value of `APP_GATEWAY_LISTENER_REGION1_CERTIFICATE_BASE64` and `APP_GATEWAY_LISTENER_REGION2_CERTIFICATE_BASE64`
        > - Ideally fetching this secret from a platform-managed secret store such as [Azure KeyVault](https://github.com/marketplace/actions/azure-key-vault-get-secrets)

        ```bash
        echo $APP_GATEWAY_LISTENER_REGION1_CERTIFICATE_BASE64
        echo $APP_GATEWAY_LISTENER_REGION2_CERTIFICATE_BASE64
        ```

    1.  Create `AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64` secret in your GitHub repository. For more information, please take a look at [Creating encrypted secrets for a repository](https://docs.github.com/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets#creating-encrypted-secrets-for-a-repository).

        > :bulb:
        >
        > - Use the env var value of `AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64`
        > - Ideally fetching this secret from a platform-managed secret store such as [Azure Key Vault](https://github.com/marketplace/actions/azure-key-vault-get-secrets)

        ```bash
        echo $AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64
        ```

    1.  Copy the GitHub workflow file into the expected directory

        ```bash
        mkdir -p .github/workflows
        cat github-workflow/aks-deploy.yaml > .github/workflows/aks-deploy.yaml
        ```

    1.  Generate cluster parameter file per region

        ```bash
        #Region1
        cat ./azuredeploy.parameters.region.json | \
        sed "s#<resource-location>#eastus2#g" | \
        sed "s#<geo-redundancy-location>#centralus#g" | \
        sed "s#<cluster-spoke-vnet-resource-id>#${RESOURCEID_VNET_BU0001A0042_03}#g" | \
        sed "s#<tenant-id-with-user-admin-permissions>#${TENANTID_K8SRBAC}#g" | \
        sed "s#<azure-ad-aks-admin-group-object-id>#${AADOBJECTID_GROUP_CLUSTERADMIN}#g" | \
        sed "s#<cluster-internal-load-balancer-ip-address>#10.243.4.4#g" | \
        sed "s#<app-instance-id>#03#g" | \
        sed "s#<log-analytics-workspace-id>#${LOGANALYTICSWORKSPACEID}#g" | \
        sed "s#<container-registry-id>#${CONTAINERREGISTRYID}#g" | \
        sed "s#<acrPrivateDns-zones-id>#${ACRPRIVATEDNSZONESID}#g" | \
        sed "s#<subdomain-name>#${CLUSTER_SUBDOMAIN_03}#g" \
        > azuredeploy.parameters.region1.json

        #Region2
        cat ./azuredeploy.parameters.region.json | \
        sed "s#<resource-location>#centralus#g" | \
        sed "s#<geo-redundancy-location>#centralus#g" | \
        sed "s#<cluster-spoke-vnet-resource-id>#${RESOURCEID_VNET_BU0001A0042_04}#g" | \
        sed "s#<tenant-id-with-user-admin-permissions>#${TENANTID_K8SRBAC}#g" | \
        sed "s#<azure-ad-aks-admin-group-object-id>#${AADOBJECTID_GROUP_CLUSTERADMIN}#g" | \
        sed "s#<cluster-internal-load-balancer-ip-address>#10.244.4.4#g" | \
        sed "s#<app-instance-id>#04#g" | \
        sed "s#<log-analytics-workspace-id>#${LOGANALYTICSWORKSPACEID}#g" | \
        sed "s#<container-registry-id>#${CONTAINERREGISTRYID}#g" | \
        sed "s#<acrPrivateDns-zones-id>#${ACRPRIVATEDNSZONESID}#g" | \
        sed "s#<subdomain-name>#${CLUSTER_SUBDOMAIN_04}#g" \
        > azuredeploy.parameters.region2.json
        ```

    1.  Push the changes to your forked repo.

        > :book: The DevOps team wants to automate their infrastructure deployments. In this case, they decided to use GitHub Actions. They are going to create a workflow for every AKS cluster instance they have to take care of.

        ```bash
        git add -u && git commit -m "setup GitHub CD workflow" && git push origin main
        ```

        > :bulb: You might want to convert this GitHub workflow into a template since your organization or team might need to handle multiple AKS clusters. For more information, please take a look at [Sharing Workflow Templates within your organization](https://docs.github.com/actions/configuring-and-managing-workflows/sharing-workflow-templates-within-your-organization).

    1.  The workflow start when a push on main is detected. Go to the Action tab in order to see the execution.

        > :book: The DevOps team monitors this Workflow execution instance. In this instance it will impact a critical piece of infrastructure as well as the management. This flow works for both new or an existing AKS cluster.

## Container registry note

:warning: To aid in ease of deployment of this cluster and your experimentation with workloads, Azure Policy and Azure Firewall are currently configured to allow your cluster to pull images from _public container registries_ such as Docker Hub. For a production system, you'll want to update Azure Policy parameter named `allowedContainerImagesRegex` in your `cluster-stamp.json` file to only list those container registries that you are willing to take a dependency on and what namespaces those policies apply to, and make Azure Firewall allowances for the same. This will protect your cluster from unapproved registries being used, which may prevent issues while trying to pull images from a registry which doesn't provide SLA guarantees for your deployment.

This deployment creates an SLA-backed Azure Container Registry for your cluster's needs. Your organization may have a central container registry for you to use, or your registry may be tied specifically to your application's infrastructure (as demonstrated in this implementation). **Only use container registries that satisfy the security and availability needs of your application.**

### Next step

:arrow_forward: [Place the cluster under GitOps management](./07-gitops.md)
