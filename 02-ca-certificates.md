# Generate Your Client-Facing and AKS Ingress Controller TLS Certificates

Now that you have the [prerequisites](./01-prerequisites.md) met, follow the steps below to create the TLS certificates that Azure Application Gateway will serve for clients connecting to your web app as well as the AKS Ingress Controller. If you already have access to an appropriate certificates, or can procure them from your organization, consider doing so and skipping the certificate generation steps. The following will describe using a self-signed certs for instructive purposes only.

## Steps

1. Generate a client-facing self-signed TLS certificate

   > :book: Contoso Bicycle needs to procure a CA certificate for the web site. As this is going to be a user-facing site, they purchase an EV cert from their CA.  This will serve in front of the Azure Application Gateway.  They will also procure another one, a standard cert, to be used with the AKS Ingress Controller. This one is not EV, as it will not be user facing.

   :warning: Do not use the certificate created by this script for actual deployments. The use of self-signed certificates are provided for ease of illustration purposes only. For your cluster, use your organization's requirements for procurement and lifetime management of TLS certificates, _even for development purposes_.

   Create the certificate for Azure Application Gateway with a common name of `bicycle.contoso.com`.

   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=bicycle.contoso.com/O=Contoso Bicycle"
   openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
   ```

1. Base64 encode the client-facing certificate

   :bulb: No matter if you used a certificate from your organization or you generated one from above, you'll need the certificate (as `.pfx`) to be base 64 encoded for proper storage in Key Vault later.

   ```bash
   export APP_GATEWAY_LISTENER_CERTIFICATE=$(cat appgw.pfx | base64 | tr -d '\n')
   ```

1. Generate the wildcard certificate for the AKS Ingress Controller

   > :book: Contoso Bicycle will also procure another TLS certificate, a standard cert, to be used with the AKS Ingress Controller. This one is not EV, as it will not be user facing. Finally the app team decides to use a wildcard certificate of `*.aks-ingress.contoso.com` for the ingress controller.

   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out traefik-ingress-internal-aks-ingress-contoso-com-tls.crt -keyout traefik-ingress-internal-aks-ingress-contoso-com-tls.key -subj "/CN=*.aks-ingress.contoso.com/O=Contoso Aks Ingress"
   ```

1. Base64 encode the AKS Ingress Controller certificate

   :bulb: No matter if you used a certificate from your organization or you generated one from above, you'll need the public certificate (as `.crt` or `.cer`) to be base 64 encoded for proper storage in Key Vault later.

   ```bash
   export AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64=$(cat traefik-ingress-internal-aks-ingress-contoso-com-tls.crt | base64 | tr -d '\n')
   ```

### Next step

:arrow_forward: [Prep for Azure Active Directory integration](./03-aad.md)
