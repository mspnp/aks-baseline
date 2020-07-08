# End-to-End Validation

Now that you have a workload deployed, the [ASP.NET Core Docker sample web app](./09-workload), you can start validating and exploring this reference implementation of the [AKS secure baseline cluster](./). In addition to the workload, there are some observability validation you can perform as well.

## Validate the Web App

This section will help you to validate the workload is exposed correctly and responding to HTTP requests.

### Steps

1. Get Public IP of Application Gateway

    > :book: The app team conducts a final acceptance test to be sure that traffic is flowing end-to-end as expected, so they place a request against the Azure Application Gateway endpoint.

    ```bash
    # query the Azure Application Gateway Public Ip
    export APPGW_PUBLIC_IP=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.appGwPublicIpAddress.value -o tsv)
    ```

1. Create `A` Record for DNS

    > You can simulate this via a local hosts file modification. You're welcome to add a real DNS entry for your specific deployment's application domain name, if you have access to do so.

    Map the Azure Application Gateway public IP address to the application domain name. To do that, please open your hosts file (`C:\Windows\System32\drivers\etc\hosts` or `/etc/hosts`) and add the following record in local host file: `${APPGW_PUBLIC_IP} bicycle.contoso.com`

1. Browse to the site (e.g. <https://bicycle.contoso.com>).

    > :bulb: A TLS warning will be present due to using a self-signed certificate.

## Validate Azure Monitor (Logs)

Azure Monitor is configured to surface cluster logs, here you can see those logs as they are generated.

### Steps

TODO

## Validate Azure Monitor (Prometheus Scraping)

Azure Monitor is configured to scrape Prometheus metrics. These steps will show you how to see those metrics.

### Steps

TODO

## Validate Azure Advisor Alerts

Azure Advisor will generate alerts on the health of your cluster and adjacent resources. This reference implementation sets up an alert that all you need to do it subscribe to. These steps will show you how.

### Steps

TODO

### Next step

:arrow_forward: [Clean Up Azure Resources](./11-cleanup.md)
