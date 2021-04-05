# End-to-End Validation

Now that you have a workload deployed, the [ASP.NET Core Docker sample web app](./09-workload.md), you can start validating and exploring this reference implementation of the [AKS secure baseline cluster](./). In addition to the workload, there are some observability validation you can perform as well.

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

## Validate Web Application Firewall functionality

Your workload is placed behind a Web Application Firewall (WAF), which has rules designed to stop intentionally malicious activity. You can test this by triggering one of the built-in rules with a request that looks malicious.

> :bulb: This reference implementation enables the built-in OWASP 3.0 ruleset, in **Prevention** mode.

### Steps

1. Browse to the site with the following appended to the URL: `?sql=DELETE%20FROM` (e.g. <https://bicycle.contoso.com/?sql=DELETE%20FROM>).
1. Observe that your request was blocked by Application Gateway's WAF rules and your workload never saw this potentially dangerous request.
1. Blocked requests (along with other gateway data) will be visible in the attached Log Analytics workspace. Execute the following query to show WAF logs, for example.

   ```
   AzureDiagnostics
   | where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
   ```

## Validate Cluster Azure Monitor Insights and Logs

Monitoring your cluster is critical, especially when you're running a production cluster. Azure Monitor is configured to surface cluster logs, here you can see those logs as they are generated. [Azure Monitor for containers](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-overview) is configured on this cluster for this purpose.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource.
1. Click _Insights_ to see see captured data.

You can also execute [queries](https://docs.microsoft.com/azure/azure-monitor/log-query/get-started-portal) on the [cluster logs captured](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-log-search).

1. In the Azure Portal, navigate to your AKS cluster resource.
1. Click _Logs_ to see and query log data.
   :bulb: There are several examples on the _Kubernetes Services_ category.

## Validate Azure Monitor for containers (Prometheus Metrics)

Azure Monitor is configured to [scrape Prometheus metrics](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-prometheus-integration) in your cluster. This reference implementation is configured to collect Prometheus metrics from two namespaces, as configured in [`container-azm-ms-agentconfig.yaml`](./cluster-baseline-settings/container-azm-ms-agentconfig.yaml). There are two pods configured to emit Prometheus metrics:

- [Traefik](./workload/traefik.yaml) (in the `a0008` namespace)
- [Kured](./cluster-baseline-settings/kured-1.4.0-dockerhub.yaml) (in the `cluster-baseline-settings` namespace)

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select your Log Analytic Workspace resource.
1. Click _Saved Searches_.

   :bulb: This reference implementation ships with some saved queries as an example of how you can write your own and manage them via ARM templates.

1. Type _Prometheus_ in the filter.
1. You are able to select and execute the saved query over the scraped metrics.

## Validate Workload Logs

The example workload uses the standard dotnet logger interface, which are captured in `ContainerLogs` in Azure Monitor. You could also include additional logging and telemetry frameworks in your workload, such as Application Insights. Here are the steps to view the built-in application logs.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select your Log Analytic Workspace resource.
1. Execute the following query

   ```
   let podInventory = KubePodInventory
   | where ContainerName endswith "aspnetcore-webapp-sample"
   | distinct ContainerID, ContainerName
   | project-rename Name=ContainerName;
   ContainerLog
   | project-away Name
   | join kind=inner
       podInventory
   on ContainerID
   | project TimeGenerated, LogEntry, Computer, Name, ContainerID
   | order by TimeGenerated desc
   ```

## Validate Azure Alerts

Azure will generate alerts on the health of your cluster and adjacent resources. This reference implementation sets up multiple alerts that you can subscribe to.

### Steps

An alert based on [Azure Monitor for containers information using a Kusto query](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-alerts) was configured in this reference implementation.

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select _Alerts_, then _Manage Rule Alerts_.
1. There is an alert called "PodFailedScheduledQuery" that will be triggered based on the custom query response.

An [Azure Advisor Alert](https://docs.microsoft.com/azure/advisor/advisor-overview) was configured as well in this reference implementation.

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select _Alerts_, then _Manage Rule Alerts_.
1. There is an alert called "AllAzureAdvisorAlert" that will be triggered based on new Azure Advisor alerts.

A series of metric alerts were configured as well in this reference implementation.

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select your cluster, then _Insights_.
1. Select _Recommended alerts_ to see those enabled. (Feel free to enable/disable as you see fit.)

## Validate Azure Container Registry Image Pulls

If you configured your third-party images to be pulled from your Azure Container Registry vs public registries, you can validate that the container registry logs show `Pull` logs for your cluster when you applied your flux configuration.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`) and then your Azure Container Registry instances (starts with `acraks`).
1. Select _Logs_.
1. Execute the following query, for whatever time range is appropriate.

   ```kusto
   ContainerRegistryRepositoryEvents
   | where OperationName == 'Pull'
   ```

1. You should see logs for CSI, flux, kured, memcached, and traefik. You'll see multiple for some as the image was pulled to multiple nodes to satisfy ReplicaSet/DaemonSet placement.

## Next step

:arrow_forward: [Clean Up Azure Resources](./11-cleanup.md)
