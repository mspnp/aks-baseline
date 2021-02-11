# Generate your Client-Facing and AKS Ingress Controller TLS Certificates

Now that you have the [prerequisites](./01-prerequisites.md) met, follow the steps below to create the TLS certificates that Azure Application Gateway will serve for clients connecting to your web app as well as the AKS Ingress Controller. If you already have access to an appropriate certificates, or can procure them from your organization, consider doing so and skipping the certificate generation steps. The following will describe using certs for instructive purposes only.

## Expected results

Following the steps below you will result the certificate needed for Azure Application Gateway and AKS Ingress Controller. All of then are needed base64.

| Object                                | Purpose                                                                     |
| ------------------------------------- | --------------------------------------------------------------------------- |
| Azure Application Gateway Certificate | They are CA certificates for tls in the cluster entry point                 |
| Aks ingress Controller                | It is self-sign test purpose cert for tls on the cluster ingress controller |

## Steps

1. Generate a client-facing TLS certificate

   > :book: Contoso Bicycle needs to procure a CA certificate for the web site. As this is going to be a user-facing site, they purchase an EV cert from their CA. This will serve in front of the Azure Application Gateway. They will also procure another one, a standard cert, to be used with the AKS Ingress Controller. This one is not EV, as it will not be user facing.

   :warning: Azure Front Door does not support self-signed certificates.

   Create a CA certificate for each Azure Application Gateway. You can use your company domain or try get a certificate for each domain using [Azure Subdomain Certificates Generation](./certificate-generation/README.md).

   :warning: We are waiting for two certificates in the following example (Please, pay attention the regions where the certs are needed). We called CLUSTER_SUBDOMAIN_03 and CLUSTER_SUBDOMAIN_04 each subdomain. You can change the name if you desire.

   ```bash
   USER_NAME=$(az ad signed-in-user show --query 'mailNickname' -o tsv)
   export CLUSTER_SUBDOMAIN_03=${USER_NAME//.}-region1
   export CLUSTER_SUBDOMAIN_04=${USER_NAME//.}-region2
   ```

   The expected result are two files like '$CLUSTER_SUBDOMAIN_03.pfx' and '$CLUSTER_SUBDOMAIN_04.pfx'.
   Please, continue with the following step only after getting that certificates.

1. Base64 encode the client-facing certificate

   :bulb: No matter if you used a certificate from your organization or you generated one from above, you'll need the certificate (as `.pfx`) to be base 64 encoded for proper storage in Key Vault later.

   ```bash
   export APP_GATEWAY_LISTENER_CERTIFICATE_BU0001A004203=$(cat $CLUSTER_SUBDOMAIN_03.pfx | base64 | tr -d '\n')
   export APP_GATEWAY_LISTENER_CERTIFICATE_BU0001A004204=$(cat $CLUSTER_SUBDOMAIN_04.pfx | base64 | tr -d '\n')
   ```

1. Generate the wildcard certificate for the AKS Ingress Controller

   > :book: Contoso Bicycle will also procure another TLS certificate, a standard cert, to be used with the AKS Ingress Controller. This one is not EV, as it will not be user facing. Finally the app team decides to use a wildcard certificate of `*.aks-ingress.contoso.com` for the ingress controller.

   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out traefik-ingress-internal-aks-ingress-contoso-com-tls.crt -keyout traefik-ingress-internal-aks-ingress-contoso-com-tls.key -subj "/CN=*.aks-ingress.contoso.com/O=Contoso Aks Ingress"
   ```

1. Base64 encode the AKS Ingress Controller certificate

   :bulb: No matter if you used a certificate from your organization or you generated one from above, you'll need the public certificate (as `.crt` or `.cer`) to be base 64 encoded for proper storage in Key Vault later.

   ```bash
   AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64=$(cat traefik-ingress-internal-aks-ingress-contoso-com-tls.crt | base64 | tr -d '\n')
   ```

### Next step

:arrow_forward: [Prep for Azure Active Directory integration](./03-aad.md)
