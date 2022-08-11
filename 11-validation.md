# End-to-End Validation

Now that you have a workload deployed, the [ASP.NET Core Docker sample web app](./10-workload.md), you can start validating and exploring this reference implementation of the [AKS Baseline cluster](./). In addition to the workload, there are some observability validation you can perform as well.

## Validate the Web App

This section will help you to validate the workload is exposed correctly and responding to HTTP requests.

### Steps

1. Get Public IP of Application Gateway

   > :book: The app team conducts a final acceptance test to be sure that traffic is flowing end-to-end as expected, so they place a request against the Azure Application Gateway endpoint.

   ```bash
   # query the Azure Application Gateway Public Ip
   APPGW_PUBLIC_IP=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.appGwPublicIpAddress.value -o tsv)
   echo APPGW_PUBLIC_IP: $APPGW_PUBLIC_IP
   ```

1. Create `A` Record for DNS

   > :bulb: You can simulate this via a local hosts file modification. You're welcome to add a real DNS entry for your specific deployment's application domain name, if you have access to do so.

   Map the Azure Application Gateway public IP address to the application domain name. To do that, please edit your hosts file (`C:\Windows\System32\drivers\etc\hosts` or `/etc/hosts`) and add the following record to the end: `${APPGW_PUBLIC_IP} bicycle.${DOMAIN_NAME_AKS_BASELINE}` (e.g. `50.140.130.120   bicycle.contoso.com`)

1. Browse to the site (e.g. <https://bicycle.contoso.com>).

   > :bulb: Remember to include the protocol prefix `https://` in the URL you type in the address bar of your browser. A TLS warning will be present due to using a self-signed certificate. You can ignore it or import the self-signed cert (`appgw.pfx`) to your user's trusted root store.

   Refresh the web page a couple of times and observe the value `Host name` displayed at the bottom of the page. As the Traefik Ingress Controller balances the requests between the two pods hosting the web page, the host name will change from one pod name to the other throughtout your queries.

## Validate reader access to the a0008 namespace. _Optional._

When setting up [Azure AD security groups](./03-aad.md) you created a group to be used as a "reader" for the namespace a0008. If you want to experience this RBAC example, you'll want to add a user to that group.

If Azure RBAC is your cluster's Kubernetes RBAC backing store, then that is all that is needed.

If instead Kubernetes RBAC is backed directly by Azure AD, then you'll need to ensure that you've updated and applied the [`rbac.yaml`](./cluster-manifests/a0008/rbac.yaml) according to the instructions found at the end of the [Azure AD configuration page](./03-aad.md).

No matter which backing store you use, the user assigned to the group will then be able to `az aks get-credentials` to the cluster and you can validate that user is limited to a _read only_ view of the a0008 namespace.

## Validate Web Application Firewall functionality

Your workload is placed behind a Web Application Firewall (WAF), which has rules designed to stop intentionally malicious activity. You can test this by triggering one of the built-in rules with a request that looks malicious.

> :bulb: This reference implementation enables the built-in OWASP 3.0 ruleset, in **Prevention** mode.

### Steps

1. Browse to the site with the following appended to the URL: `?sql=DELETE%20FROM` (e.g. <https://bicycle.contoso.com/?sql=DELETE%20FROM>).
1. Observe that your request was blocked by Application Gateway's WAF rules and your workload never saw this potentially dangerous request.
1. Blocked requests (along with other gateway data) will be visible in the attached Log Analytics workspace. 

   Browse to the Application Gateway in the resource group `rg-bu0001-a0008` and navigate to the _Logs_ blade. Execute the following query below to show WAF logs and see that the request was rejected due to a _SQL Injection Attack_ (field _Message_).

   > :warning: Note that it may take a couple of minutes until the logs are transferred from the Application Gateway to the Log Analytics Workspace. So be a little patient if the query does not immediatly return results after sending the https request in the former step. 

   ```
   AzureDiagnostics
   | where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
   ```

## Validate Cluster Azure Monitor Insights and Logs

Monitoring your cluster is critical, especially when you're running a production cluster. Therefore, your AKS cluster is configured to send [diagnostic information](https://docs.microsoft.com/azure/aks/monitor-aks) of categories _cluster-autoscaler_, _kube-controller-manager_, _kube-audit-admin_ and _guard_ to the Log Analytics Workspace deployed as part of the [bootstrapping step](./05-bootstrap-prep.md). Additionally, [Azure Monitor for containers](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-overview) is configured on your cluster to capture metrics and logs from your workload containers. Azure Monitor is configured to surface cluster logs, here you can see those logs as they are generated. 

:bulb: If you need to inspect the behavior of the Kubernetes scheduler, enable the log category _kube-scheduler_ (either through the _Diagnostic Settings_ blade of your AKS cluster or by enabling the category in your `cluster-stamp.bicep` template). Note that this category is quite verbose and will impact the cost of your Log Analytics Workspace.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource.
1. Click _Insights_ to see captured data.

You can also execute [queries](https://docs.microsoft.com/azure/azure-monitor/log-query/get-started-portal) on the [cluster logs captured](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-log-search).

1. In the Azure Portal, navigate to your AKS cluster resource.
1. Click _Logs_ to see and query log data.
   :bulb: There are several examples on the _Kubernetes Services_ category.

## Validate Azure Monitor for containers (Prometheus Metrics)

Azure Monitor is configured to [scrape Prometheus metrics](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-prometheus-integration) in your cluster. This reference implementation is configured to collect Prometheus metrics from two namespaces, as configured in [`container-azm-ms-agentconfig.yaml`](./cluster-baseline-settings/container-azm-ms-agentconfig.yaml). There are two pods configured to emit Prometheus metrics:

- [Traefik](./workload/traefik.yaml) (in the `a0008` namespace)
- [Kured](./cluster-baseline-settings/kured.yaml) (in the `cluster-baseline-settings` namespace)

 :bulb: This reference implementation ships with two queries (_All collected Prometheus information_ and _Kubenertes node reboot requested_) in a Log Analytics Query Pack as an example of how you can write your own and manage them via ARM templates.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select your Log Analytic Workspace resource and open the _Logs_ blade.
1. Find the one of the above queries in the _Containers_ category.
1. You are able to select and execute the saved query over the scraped metrics.

## Validate Workload Logs

The example workload uses the standard dotnet logger interface, which are captured in `ContainerLogs` in Azure Monitor. You could also include additional logging and telemetry frameworks in your workload, such as Application Insights. Here are the steps to view the built-in application logs.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select your Log Analytic Workspace resource and open the _Logs_ blade.
1. Execute the following query

   ```
   let podInventory = KubePodInventory
   | where ContainerName endswith "aspnet-webapp-sample"
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
1. Select _Alerts_, then _Alert Rules_.
1. There is an alert titled "[your cluster name] Scheduled Query for Pod Failed Alert" that will be triggered based on the custom query response.

An [Azure Advisor Alert](https://docs.microsoft.com/azure/advisor/advisor-overview) was configured as well in this reference implementation.

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select _Alerts_, then _Alert Rules_.
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

1. You should see logs for kured. You'll see multiple for some as the image was pulled to multiple nodes to satisfy ReplicaSet/DaemonSet placement.

## Next step

:arrow_forward: [Clean Up Azure Resources](./12-cleanup.md)
