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

   > :bulb: You can simulate this via a local hosts file modification. You're welcome to add a real DNS entry for your specific deployment's application domain name, if you have access to do so.

   Map the Azure Application Gateway public IP address to the application domain name. To do that, please edit your hosts file (`C:\Windows\System32\drivers\etc\hosts` or `/etc/hosts`) and add the following record to the end: `${APPGW_PUBLIC_IP} bicycle.contoso.com`

1. Browse to the site (e.g. <https://bicycle.contoso.com>).

   > :bulb: A TLS warning will be present due to using a self-signed certificate.

## Validate Azure Monitor (Logs)

Monitoring your containers is critical, especially when you're running a production cluster. Azure Monitor is configured to surface cluster logs, here you can see those logs as they are generated.

### Steps

- [Azure Monitor for container is configured](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-overview).

  - Open the Azure Portal and sign in
  - On your cluster resource group (rg-bu0001a0008),
  - Select your AKS resource,
  - And then _Insights_

- It is possible to execute [Kusto queries](https://docs.microsoft.com/azure/azure-monitor/log-query/get-started-portal) based on your [cluster information](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-log-search).

  - Open the Azure Portal and sign in
  - On your cluster resource group (rg-bu0001a0008),
  - Select your AKS resource,
  - And then _Logs_
  - There are serveral examples on the _Kubertenes Services_ category.

## Validate Azure Monitor for containers (Prometheus Metrics)

[Azure Monitor is configured to scrape Prometheus metrics](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-prometheus-integration).

The cluster is configured to collect Prometheus metrics from two namespaces, as configured in [`container-azm-ms-agentconfig.yaml`](./cluster-baseline-settings/container-azm-ms-agentconfig.yaml)). It is needed some pod that support emitting Prometheus metrics and it has been configured, our examples are:

- a0008, here is collecting [treafik data](./workload/traefik.yaml#L199-L201)
- cluster-baseline-settings, here is collecting [kured data](./cluster-baseline-settings/kured-1.4.0-dockerhub.yaml#L80-L82)

### Steps

- This reference implementation ships with some saved queries as an example of how you can write your own and manage them via IaC. To see them in the Azure Portal:

  - Open the Azure Portal and sign in
  - On your cluster resource group (rg-bu0001a0008),
  - Select your Log Analytic Workpace resource,
  - Then _Saved Searches_.
  - Write _Prometheus_ in the filter
  - You are able to select and execute anyone

## Validate Azure Alerts

Azure will generate alerts on the health of your cluster and adjacent resources. This reference implementation sets up an alert that all you need to do it subscribe to.

### Steps

- An alert based on [Azure Monitor for containers information using a kusto query](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-alerts) was configured. Also you can set up your own alerts based on your own queries.

  - Open the Azure Portal and sign in
  - On your cluster resource group (rg-bu0001a0008),
  - Select your _Alerts_,
  - And then _Manage Rule Alerts_
  - There is an alert called "PodFailedPhase" based on a Kusto query described on the article.

* An [Azure Advisor Alert](https://docs.microsoft.com/azure/advisor/advisor-overview) was configured as well, you can improve the performance, security, and reliability of your resources, as you identify opportunities to reduce your overall Azure spend. You can [customize the azure advisor alert or create new ones](https://docs.microsoft.com/azure/advisor/advisor-alerts-portal).

  - Open the Azure Portal and sign in
  - On your cluster resource group (rg-bu0001a0008),
  - Select your _Alerts_,
  - And then _Manage Rule Alerts_
  - There is an alert called "AllAzureAdvisorAlert"

### Next step

:arrow_forward: [Clean Up Azure Resources](./11-cleanup.md)
