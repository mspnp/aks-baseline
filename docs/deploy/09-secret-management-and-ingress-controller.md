# Configure AKS ingress controller with Azure Key Vault integration

Previously you have configured [workload prerequisites](./08-workload-prerequisites.md). The following steps configure Traefik, the AKS ingress solution used in this reference implementation, so that it can securely expose the web app to your Application Gateway.

## Steps

1. Get the AKS Ingress Controller managed identity details.

   ```bash
   INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
   echo INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID: $INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID
   ```

1. Ensure your bootstrapping process has created the following namespace.

   ```bash
   # press Ctrl-C once you receive a successful response
   kubectl get ns a0008 -w
   ```

1. Create the ingress controller's Secret Provider Class resource.

   > The ingress controller will be exposing the wildcard TLS certificate you created in a prior step. It uses the Azure Key Vault CSI Provider to mount the certificate which is managed and stored in Azure Key Vault. Once mounted, Traefik can use it.
   >
   > Create a `SecretProviderClass` resource with your federated identity and Azure Key Vault parameters for the [Azure Key Vault Provider for Secrets Store CSI Driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure).

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
       clientID: $INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID
       usePodIdentity: "false"
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
       tenantID: $TENANTID_AZURERBAC_AKS_BASELINE
   EOF
   ```

1. Optional: Sign up for a Docker Hub account.

   When Azure Container Registry imports the Traefik container image, it's likely to fail because the Docker Hub service performs rate limiting. As a service that shares an IP address between many different Azure customers, Azure Container Registry frequently hits the rate limits imposed by Docker Hub. You can avoid this issue by using your own [Docker Hub account](https://www.docker.com/pricing) and providing the credentials so that Azure Container Registry can use it when it's importing the image.

   Note your Docker Hub user name and either a password or [personal access token](https://docs.docker.com/docker-hub/access-tokens/).

1. Import the Traefik container image to your container registry.

   > Public container registries are subject to faults such as outages (no SLA) or request throttling. Interruptions like these can be crippling for an application that needs to pull an image *right now*. To minimize the risks of using public registries, store all applicable container images in a registry that you control, such as the SLA-backed Azure Container Registry.

   If you have your own Docker Hub account, use the following command to provide the credentials during the import process:

   ```bash
   # Import ingress controller image hosted in public container registries
   az acr import --source docker.io/library/traefik:v3.1 -n $ACR_NAME_AKS_BASELINE --username YOUR_DOCKER_HUB_USERNAME --password YOUR_DOCKER_HUB_PASSWORD_OR_PERSONAL_ACCESS_TOKEN
   ```

   If you don't have a Docker Hub account, use the following command, but note that you might receive a rate limit failure and need to retry repeatedly:

   ```bash
   # Import ingress controller image hosted in public container registries
   az acr import --source docker.io/library/traefik:v3.1 -n $ACR_NAME_AKS_BASELINE
   ```

1. When the cluster was deployed, the Bicep deployment decided on the fixed private IP address to use for the AKS internal load balancer ingress controller's service. Retrieve that IP address so we can configure it in the Traefik deployment, which will create the load balancer.

   ```bash
   INGRESS_CONTROLLER_SERVICE_ILB_IPV4_ADDRESS_BU0001A0008=$(az deployment group show -g rg-bu0001a0008 -n cluster-stamp --query properties.outputs.ilbIpAddress.value -o tsv)
   echo INGRESS_CONTROLLER_SERVICE_ILB_IPV4_ADDRESS_BU0001A0008: $INGRESS_CONTROLLER_SERVICE_ILB_IPV4_ADDRESS_BU0001A0008
   ```

1. Install the Traefik Ingress Controller.

   > Install the Traefik Ingress Controller; it will use the mounted TLS certificate provided by the CSI driver, which is the in-cluster secret management solution.

   > If you used your own fork of this GitHub repo, update the one `image:` value in [`traefik.yaml`](./workload/traefik.yaml) to reference your container registry instead of the default public container registry and change the following URL to point to yours as well.

   :warning: Deploying the Traefik `traefik.yaml` file unmodified from this repo will be deploying your workload to take dependencies on a public container registry. This is generally okay for learning/testing, but not suitable for production. Before going to production, ensure *all* image references are from *your* container registry or another that you feel confident relying on.

   ```bash
   sed -i "s#<ingress-controller-ilb-ipv4-address>#${INGRESS_CONTROLLER_SERVICE_ILB_IPV4_ADDRESS_BU0001A0008}#g" workload/traefik.yaml

   kubectl create -f workload/traefik.yaml
   ```

1. Wait for Traefik to be ready.

   > During Traefik's pod creation process, Azure Key Vault will be accessed to get the required certs needed for pod volume mount (csi). This sometimes takes a bit of time but will eventually succeed if properly configured.

   ```bash
   kubectl wait -n a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=traefik-ingress-ilb --timeout=90s
   ```

### Next step

:arrow_forward: [Deploy the Workload](./10-workload.md)