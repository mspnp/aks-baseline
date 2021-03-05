# Generate your Client-Facing and AKS Ingress Controller TLS Certificates

Now that the [hub-spoke network is provisioned](./03-networking.md), you can follow the steps below to create the TLS certificates for each region that Azure Application Gateway will serve for clients connecting to your web app as well as the AKS Ingress Controller. If you already have access to an appropriate certificates, or can procure them from your organization, consider doing so and skipping the certificate generation steps. The following will describe using certs for instructive purposes only.

## Expected results

Following the steps below you will result the certificate needed for Azure Application Gateway and AKS Ingress Controller. All of then are needed base64.

| Object                                | Purpose                                                                     |
| ------------------------------------- | --------------------------------------------------------------------------- |
| Azure Application Gateway Certificate | They are CA certificates for tls in the cluster entry point                 |
| Aks ingress Controller                | It is self-sign test purpose cert for tls on the cluster ingress controller |

## Steps

1. Generate a client-facing TLS certificate

   > :book: The organization needs to procure a CA certificate for the web site. As this is going to be a user-facing site, they purchase an EV cert from their CA. This will serve in front of the Azure Application Gateway. They will also procure another one, a standard cert, to be used with the AKS Ingress Controller. This one is not EV, as it will not be user facing.

   :warning: Azure Front Door does not support self-signed certificates.

   Create a CA certificate for each Azure Application Gateway. You can try get a certificate for each domain using [Azure Subdomain Certificates Generation](./certificate-generation/README.md).

   We are waiting for two certificates:

   ```bash
   ## Get the FQDN which we need certificates for
   APPGW_FQDN_BU0001A0042_03=$(az deployment group show -g rg-enterprise-networking-spokes -n  spoke-BU0001A0042-03 --query properties.outputs.appGwFqdn.value -o tsv)
   APPGW_FQDN_BU0001A0042_04=$(az deployment group show -g rg-enterprise-networking-spokes -n  spoke-BU0001A0042-04 --query properties.outputs.appGwFqdn.value -o tsv)

   ## Get the Public Ip resource Id. They will be useful in order to generate the certificates base on them.
   APPGW_IP_RESOURCE_ID_03=$(az deployment group show -g rg-enterprise-networking-spokes -n  spoke-BU0001A0042-03 --query properties.outputs.appGatewayPublicIp.value -o tsv)
   APPGW_IP_RESOURCE_ID_04=$(az deployment group show -g rg-enterprise-networking-spokes -n  spoke-BU0001A0042-04 --query properties.outputs.appGatewayPublicIp.value -o tsv)

   ## Get the subdomain names selected by the script
   CLUSTER_SUBDOMAIN_03=$(az deployment group show -g rg-enterprise-networking-spokes -n  spoke-BU0001A0042-03 --query properties.outputs.subdomainName.value -o tsv)
   CLUSTER_SUBDOMAIN_04=$(az deployment group show -g rg-enterprise-networking-spokes -n  spoke-BU0001A0042-04 --query properties.outputs.subdomainName.value -o tsv)

   ##Show the certificates needed
   echo $APPGW_FQDN_BU0001A0042_03
   echo $APPGW_FQDN_BU0001A0042_04
   ```

   The expected result are two files like '$CLUSTER_SUBDOMAIN_03.pfx' and '$CLUSTER_SUBDOMAIN_04.pfx'.
   Please, continue with the following step only after getting that certificates.

1. Base64 encode the client-facing certificate

   :bulb: No matter if you used a certificate from your organization or you generated one from above, you'll need the certificate (as `.pfx`) to be base 64 encoded for proper storage in Key Vault later.

   ```bash
   export APP_GATEWAY_LISTENER_REGION1_CERTIFICATE_BASE64=$(cat $CLUSTER_SUBDOMAIN_03.pfx | base64 | tr -d '\n')
   export APP_GATEWAY_LISTENER_REGION2_CERTIFICATE_BASE64=$(cat $CLUSTER_SUBDOMAIN_04.pfx | base64 | tr -d '\n')
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

:arrow_forward: [Deploy the AKS cluster prerequisites](./05-cluster-prerequisites.md)
