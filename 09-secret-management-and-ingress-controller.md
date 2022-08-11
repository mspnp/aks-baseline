# Configure AKS Ingress Controller with Azure Key Vault integration

Previously you have configured [workload prerequisites](./08-workload-prerequisites.md). These steps configure Traefik, the AKS ingress solution used in this reference implementation, so that it can securely expose the web app to your Application Gateway.

## Steps

1. Get the AKS Ingress Controller Managed Identity details.

   ```bash
   TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerPodManagedIdentityResourceId.value -o tsv)
   TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
   echo TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID: $TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID
   echo TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID: $TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID
   ```

1. Ensure your bootstrapping process has created the following namespace.

   ```bash
   # press Ctrl-C once you receive a successful response
   kubectl get ns a0008 -w
   ```

1. Create Traefik's Azure Managed Identity binding.

   > Create the Traefik Azure Identity and the Azure Identity Binding to let Azure Active Directory Pod Identity to get tokens on behalf of the Traefik's User Assigned Identity and later on assign them to the Traefik's pod.

   ```bash
   cat <<EOF | kubectl create -f -
   apiVersion: aadpodidentity.k8s.io/v1
   kind: AzureIdentity
   metadata:
     name: podmi-ingress-controller-identity
     namespace: a0008
   spec:
     type: 0
     resourceID: $TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID
     clientID: $TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID
   ---
   apiVersion: aadpodidentity.k8s.io/v1
   kind: AzureIdentityBinding
   metadata:
     name: podmi-ingress-controller-binding
     namespace: a0008
   spec:
     azureIdentity: podmi-ingress-controller-identity
     selector: podmi-ingress-controller
   EOF
   ```

1. Create the Traefik's Secret Provider Class resource.

   > The Ingress Controller will be exposing the wildcard TLS certificate you created in a prior step. It uses the Azure Key Vault CSI Provider to mount the certificate which is managed and stored in Azure Key Vault. Once mounted, Traefik can use it.
   >
   > Create a `SecretProviderClass` resource with with your Azure Key Vault parameters for the [Azure Key Vault Provider for Secrets Store CSI driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure).

   ```bash
   cat <<EOF | kubectl create -f -
   apiVersion: secrets-store.csi.x-k8s.io/v1
   kind: SecretProviderClass
   metadata:
     name: aks-ingress-tls-secret-csi-akv
     namespace: a0008
   spec:
     provider: azure
     parameters:
       usePodIdentity: "true"
       useVMManagedIdentity: "false"
       keyvaultName: $KEYVAULT_NAME_AKS_BASELINE
       objects:  |
         array:
           - |
             objectName: traefik-ingress-internal-aks-ingress-tls
             objectAlias: tls.crt
             objectType: cert
           - |
             objectName: traefik-ingress-internal-aks-ingress-tls
             objectAlias: tls.key
             objectType: secret
       tenantId: $TENANTID_AZURERBAC_AKS_BASELINE
   EOF
   ```

1. Import the Traefik container image to your container registry.

   > Public container registries are subject to faults such as outages (no SLA) or request throttling. Interruptions like these can be crippling for an application that needs to pull an image _right now_. To minimize the risks of using public registries, store all applicable container images in a registry that you control, such as the SLA-backed Azure Container Registry.

   ```bash
   # Import ingress controller image hosted in public container registries
   az acr import --source docker.io/library/traefik:v2.8.1 -n $ACR_NAME_AKS_BASELINE
   ```

1. Install the Traefik Ingress Controller.

   > Install the Traefik Ingress Controller; it will use the mounted TLS certificate provided by the CSI driver, which is the in-cluster secret management solution.

   > If you used your own fork of this GitHub repo, update the one `image:` value in [`traefik.yaml`](./workload/traefik.yaml) to reference your container registry instead of the default public container registry and change the URL below to point to yours as well.

   :warning: Deploying the traefik `traefik.yaml` file unmodified from this repo will be deploying your workload to take dependencies on a public container registry. This is generally okay for learning/testing, but not suitable for production. Before going to production, ensure _all_ image references are from _your_ container registry or another that you feel confident relying on.

   ```bash
   kubectl create -f https://raw.githubusercontent.com/mspnp/aks-baseline/main/workload/traefik.yaml
   ```

1. Wait for Traefik to be ready.

   > During Traefik's pod creation process, AAD Pod Identity will need to retrieve a token for Azure Key Vault. This process can take time to complete and it's possible for the pod volume mount to fail during this time but the volume mount will eventually succeed. For more information, please refer to the [Pod Identity documentation](https://azure.github.io/secrets-store-csi-driver-provider-azure/configurations/identity-access-modes/pod-identity-mode/).

   ```bash
   kubectl wait -n a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=traefik-ingress-ilb --timeout=90s
   ```

## Workload identities

This reference implementation uses the Azure AD Pod Identities feature to allow Azure Managed Identities to be associated with the cluster and then associated with pods via the `AzureIdentity` CRD. This feature is in preview and will eventually be replaced with [Azure AD Workload Identities](https://azure.github.io/azure-workload-identity) which approaches the relationship between workloads and their Azure AD identities differently. This Workload Identity feature is also still in preview and will be having additional capabilities built out, such as supporting Azure Managed Identities, to reach a similar feature state as Azure AD Pod Identities. Components like Azure Key Vault Provider for Secrets Store CSI driver will be supporting Workload Identities as an alternative to the original Azure AD Pod Identities feature over time.

This reference implementation does enable the required OIDC Issuer Profile so that you can [begin to use](https://azure.github.io/azure-workload-identity/docs/quick-start.html) the workload identity feature for your applications that can be written to support the new model. Expect updates to this reference implementation as the features and the integration of Azure AD Workload Identities evolve.

### Next step

:arrow_forward: [Deploy the Workload](./10-workload.md)
