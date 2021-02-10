## Certificate Authority generation for an Azure domain with your subdomain

Many times we need a CA certificate, and this kind of certificates cost money and you need to own your domain.  
In Azure there are services that do not support self-sign certificates, even though we are doing tests (Ex. Azure Front Door).  
In order to do some test on Azure, we can create a valid CA certificates for free.  
This article allows you generate a CA certificate for your subdomain inside Azure.  
For example

```bash
mysubdomain.eastus.cloudapp.azure.com
```

It is based on [Let's Encrypt](https://letsencrypt.org/). Let's Encrypt is a non-profit certificate authority run by Internet Security Research Group (ISRG) that provides X.509 certificates for Transport Layer Security (TLS) encryption at no charge

## Prerequisites

1. An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
1. It is needed to install [Cerbot](https://certbot.eff.org/). Certbot is a free, open source software tool for automatically using Let’s Encrypt certificates on manually-administrated websites to enable HTTPS.
1. [Install openssl tool](https://www.openssl.org/). OpenSSL is a robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols. It is also a general-purpose cryptography library.
1. Latest [Azure CLI installed](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) or you can perform this from Azure Cloud Shell by clicking below.

   [![Launch Azure Cloud Shell](https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)

## Steps

- Log in in your account and select the subscription
  > :book: If you have one subscription the selection is not be needed

```bash
## Login into azure
az login
## Choose your Azure subscription
az account set -s XXXX
```

- :rocket: Create the Azure resources  
  In order to create a certificate we need to demonstrate domain control.
  We are going to use a Azure Application Gateway on top of Azure Blob Storage to do that.

```bash
#Your resource group name
RGNAME=rg-certi-let-encrypt
#Azure location of the domain
LOCATION=eastus
#Your subdomain name
DOMAIN_NAME=mysubdomain

# Resource group creation
az group create --name "${RGNAME}" --location "${LOCATION}"

# Resource deployment. Public Ip (with DNS name), Virtual Network, Storage Account and Application Gateway
az deployment group create -g "${RGNAME}" --template-file "resources-stamp.json"  --name "cert-0001" --parameters location=$LOCATION subdomainName=$DOMAIN_NAME

#Read the url generated. We will generate a certificate for this domain
FQDN=$(az deployment group show -g $RGNAME -n cert-0001 --query properties.outputs.fqdn.value -o tsv)
```

- :heavy_plus_sign: Add a Azure Blob container and upload a file

```bash
# Create a Container on the Storage Account provided
az storage container create --account-name $DOMAIN_NAME --name verificationdata --auth-mode login --public-access container

# Create a Local File
echo Microsoft>test.txt

# Upload that file
az storage blob upload \
 --account-name $DOMAIN_NAME \
 --container-name verificationdata \
 --name test.txt \
 --file ./test.txt \
 --auth-mode key

```

- :heavy_check_mark: Checking the if the resource created are working

```bash
# We can access the file inside the blob
echo https://$DOMAIN_NAME.blob.core.windows.net/verificationdata/test.txt

# The Azure Application Gateway is exposing the Azure Blob
echo http://$FQDN/verificationdata/test.txt

# The Azure Application Gateway rewrite rule is working
echo http://$FQDN/.well-known/acme-challenge/test
```

- :key: Generate certificate base on [Cerbot](https://certbot.eff.org/)

Installing cerbot using linux could be as easy as

```bash
sudo apt-get install certbot
```

You can check how to install in your platform in the [Cerbot](https://certbot.eff.org/) site.

Please, Execute a command like the following with administration privilege

```bash
sudo certbot certonly --email changeme@mail.com -d $FQDN --agree-tos --manual
```

At this point you need to follow the Cerbot instructions
![At this point you need to follow the Cerbot instructions](./cerbot.png)

1. Create a file name with the name presenting by Cerbot during the execution, with txt extension,  
   `Ex: -Nahn2wS1fLeqGwqjDBIWxSpL5U4mlb_oA50wsPeoqk.txt`
2. Add inside the content presented by Cerbot,  
   `Ex: -Nahn2wS1fLeqGwqjDBIWxSpL5U4mlb_oA50wsPeoqk.T_a4tluV9By4PqiMY4Xz5iLe5ty1whK_vNK21LY6ZTU`
3. Upload the generated file inside the _verificationdata_ container in any way (by command line or azure portal as you prefer) Ex:

```bash
az storage blob upload \
 --account-name $DOMAIN_NAME \
 --container-name verificationdata \
 --name -Nahn2wS1fLeqGwqjDBIWxSpL5U4mlb_oA50wsPeoqk.txt \
 --file ./-Nahn2wS1fLeqGwqjDBIWxSpL5U4mlb_oA50wsPeoqk.txt \
 --auth-mode key
```

4. Test the url presented by cerbot, Ex:

```bash
http://mysubdomain.eastus.cloudapp.azure.com/.well-known/acme-challenge/-Nahn2wS1fLeqGwqjDBIWxSpL5U4mlb_oA50wsPeoqk
```

5. If the test is working, please press Enter
6. You should get a message about the cert was generated

- :page_with_curl: We need to generate the pfx

1. Take the key files

```bash
mkdir files
sudo cp /etc/letsencrypt/live/$FQDN/privkey.pem ./files
sudo cp /etc/letsencrypt/live/$FQDN/cert.pem ./files
sudo cp /etc/letsencrypt/live/$FQDN/chain.pem ./files
cd files
```

2. Generate pfx with or without password as you need

```bash
#Password-less
openssl pkcs12 -export -out $DOMAIN_NAME.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem -passout pass:
#With password
openssl pkcs12 -export -out $DOMAIN_NAME.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem
```

- :thumbsup: You have your CA valid pfx certificate for your domain on the directory  
  You will able to find $DOMAIN_NAME.pfx file on the current folder

### :broom: Delete Azure resources

```bash
az group delete -n $RGNAME --yes

```

### :book: Generate extra certificate

If you need to generate other certificates in the same region, before deleting the resources, you could

1. Set the new values in the variables, Ex.

```bash
FQDN=mysecondsubdomain.eastus.cloudapp.azure.com
DOMAIN_NAME=mysecondsubdomain
```

2. In Azure Portal Change the name for the Public IP  
   Public IP -> Configuration -> DNS name label  
   Set the same value than $DOMAIN_NAME

3. Go back to the root folder

```bash
cd ..
```

4. Start again on the step "Generate certificate base on [Cerbot](https://certbot.eff.org/)"
