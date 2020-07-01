# Test the web app

Previously you have deployed an [ASP.NET Core Docker sample web app](./08-workload). This
section will help you to validate the workload is exposed correctly and
responding to Http requests.

---

The app team conducts a final acceptance test to be sure that traffic is flowing end-to-end as expected, so they place a request against the Azure Application Gateway endpoint.

```bash
# query the Azure Application Gateway Public Ip
export APPGW_PUBLIC_IP=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.appGwPublicIpAddress.value -o tsv)
```

1. Map the Azure Application Gateway public ip address to the application domain name. To do that, please open your hosts file (`C:\windows\system32\drivers\etc\hosts` or `/etc/hosts`) and add the following record in local host file:
`${APPGW_PUBLIC_IP} bicycle.contoso.com`

1. In your browser, go to <https://bicycle.contoso.com>. A TLS warning will be present, due to using a self-signed cert.
---
Next Step: [Cleanup](./10-cleanup.md)
