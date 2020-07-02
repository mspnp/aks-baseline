# Acquire the CA certificates for the Azure Application Gateway

Now that you have the [prerequisites](./01-prerequisites) met, follow the steps below to create the TLS certificate that Azure Application Gateway will serve for clients connecting to your website.

If you already have access to an appropriate certificate, or can procure one from your organization, consider doing so and skipping step 1. The following will describe using a self-signed cert for instructive purposes only.

## Steps

1. Generate a self-signed TLS certificate

   > :book: Contoso Bicycle needs to procure a CA certificate for the web site. As this is going to be a user-facing site, they purchase an EV cert from their CA.  This will serve in front of the Azure Application Gateway.  They will also procure another one, a standard cert, to be used with the AKS Ingress Controller. This one is not EV, as it will not be user facing.

   :warning: Do not use the certificate created by this scripts for actual deployments. The use of self-signed certificates are provided for ease of illustration purposes only. For your cluster, use your organization's requirements for procurement and lifetime management of TLS certificates, _even for development purposes_.

   Create the certificate for Azure Application Gateway with a common name of `bicycle.contoso.com`. When we get to the workload steps, a second TLS certificate is going to be generated, but that one will be generated directly from your Azure Key Vault.

   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=bicycle.contoso.com/O=Contoso Bicycle"
   openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
   ```

1. Base64 encode the certificate

   No matter if you used a certificate from your organization or you generated one from above, you'll need the certificate (as `.pfx`) to be base 64 encoded for proper storage in Key Vault later.

   ```bash
    export APP_GATEWAY_LISTENER_CERTIFICATE=$(cat appgw.pfx | base64 -w 0)
    ```

### Next step

-> [Prep for Azure Active Directory integration](./03-aad.md)
