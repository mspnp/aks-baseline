## Valid Certificate Generation for an Azure domain with your subdomain

This article allows you generate a valid Certificate Authority certificate for your subdomain inside Azure.  
For example

```bash
mysubdomain.eastus.cloudapp.azure.com
```

It is based on [Let's Encrypt](https://letsencrypt.org/)

## Prerequisites

1. An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
1. It is needed to install [Cerbot](https://certbot.eff.org/). Certbot is a free, open source software tool for automatically using Let’s Encrypt certificates on manually-administrated websites to enable HTTPS.
1. [Install openssl tool](https://www.openssl.org/). OpenSSL is a robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols. It is also a general-purpose cryptography library.
1. Latest [Azure CLI installed](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) or you can perform this from Azure Cloud Shell by clicking below.

   [![Launch Azure Cloud Shell](https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)

## Steps

- Log in in your account and select the subscription

```bash
MAIN_SUBSCRIPTION=XXXX
az login
az account set -s $MAIN_SUBSCRIPTION
```

- Create the Azure resources
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

# Resource deployment. Public Ip (with DNS name), Virtal Network, Storage Account and Application Gateway
az deployment group create -g "${RGNAME}" --template-file "resources-stamp.json"  --name "cert-0001" --parameters location=$LOCATION subdomainName=$DOMAIN_NAME

#Read the url generated. We will generate a certificate for this domain
FQDN=$(az deployment group show -g $RGNAME -n cert-0001 --query properties.outputs.fqdn.value -o tsv)
```

- Add a Azure Blob container and upload a file

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

- Checking it is working

```bash
# We can access the file inside the blob
echo https://$DOMAIN_NAME.blob.core.windows.net/verificationdata/test.txt

# The Azure Application Gateway is exposing the Azure Blob
echo http://$FQDN/verificationdata/test.txt

# The Azure Application Gateway  rewrite rule is working
echo http://$FQDN/.well-known/acme-challenge/test
```

- Generate certificate base on [Cerbot](https://certbot.eff.org/)

Installing cerbot using linux could be as easy as

```bash
sudo apt-get install certbot
```

You can check how to install in your platform in the [Cerbot](https://certbot.eff.org/) site.

Please, Execute the following command with administration privilege

```bash
sudo certbot certonly --email your@mail.com -d $FQDN --agree-tos --manual
```

At this point you need to follow the Cerbot instructions

1. Create a file name with the name presenting by Cerbot during the execution, with txt extension, Ex: 4FCuByAUW3weHUCHHzZKEQLFUQTJIpsULlfHvBthUNo.txt
1. Add inside the content presented by Cerbot
1. Upload the file in any way (by command line or azure portal as you prefer) Ex:

```bash
az storage blob upload \
 --account-name $DOMAIN_NAME \
 --container-name verificationdata \
 --name 4FCuByAUW3weHUCHHzZKEQLFUQTJIpsULlfHvBthUNo.txt \
 --file ./4FCuByAUW3weHUCHHzZKEQLFUQTJIpsULlfHvBthUNo.txt \
 --auth-mode key
```

1. Test the url presented by cerbot, EX:

```bash
http://mysubdomain.eastus.cloudapp.azure.com/.well-known/acme-challenge/yuV9ui3A1LEdSMpMmxhkapiKRctuL-C0RUp444QjDfs
```

1. If the test is working, please press Enter
1. You should get a message about the cert was generated

- We need to generate the pfx  
  Take the key files

```bash
mkdir files
sudo cp /etc/letsencrypt/live/$FQDN/privkey.pem ./files
sudo cp /etc/letsencrypt/live/$FQDN/cert.pem ./files
sudo cp /etc/letsencrypt/live/$FQDN/chain.pem ./files
cd files
```

Generate pfx with or without password as you need

```bash
#Password-less
openssl pkcs12 -export -out $DOMAIN_NAME.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem -passout pass:
#With password
openssl pkcs12 -export -out $DOMAIN_NAME.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem
```

- You have your CA valid pfx certificate for your domain on the directory

### Delete Azure resources

```bash
az group delete -n $RGNAME --yes

```
