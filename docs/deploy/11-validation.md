# End-to-end validation

Now that you have a workload deployed, the [ASP.NET Core sample web app](./10-workload.md), you can start validating and exploring this reference implementation of the [AKS baseline cluster](../../). In addition to the workload, there is some observability validation you can perform as well.

## Validate the web app

This section will help you to validate the workload is exposed correctly and responding to HTTP requests.

### Steps

1. Get the public IP address of Application Gateway.

   > :book: The workload team conducts a final acceptance test to be sure that traffic is flowing end-to-end as expected, so they place a request against the Azure Application Gateway endpoint.

   ```bash
   # query the Azure Application Gateway Public Ip
   APPGW_PUBLIC_IP=$(az deployment group show --resource-group rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE} -n spoke-BU0001A0008 --query properties.outputs.appGwPublicIpAddress.value -o tsv)
   echo APPGW_PUBLIC_IP: $APPGW_PUBLIC_IP
   ```

1. Create an `A` record for DNS.

   > :bulb: You can simulate this via a local hosts file modification. You're welcome to add a real DNS entry for your specific deployment's application domain name, if you have access to do so.

   Map the Azure Application Gateway public IP address to the application domain name. To do that, edit your hosts file (`C:\Windows\System32\drivers\etc\hosts` or `/etc/hosts`) and add the following record to the end:
   
   ```
   ${APPGW_PUBLIC_IP} bicycle.${DOMAIN_NAME_AKS_BASELINE}
   ```
   
   For example, your hosts file edit might look similar to this:

   ```
   50.140.130.120   bicycle.contoso.com
   ```

1. Browse to the site (<https://bicycle.contoso.com>).

   > :bulb: Remember to include the protocol prefix `https://` in the URL you type in the address bar of your browser. A TLS warning will be present due to using a self-signed certificate. You can ignore it or import the self-signed cert (`appgw.pfx`) to your user's trusted root store.

   Refresh the web page a couple of times and observe the value `Host name` displayed at the bottom of the page. As the Traefik Ingress Controller balances the requests between the two pods hosting the web page, the host name will change from one pod name to the other throughout your queries.

## Validate reader access to the a0008 namespace. *Optional.*

When setting up [Microsoft Entra security groups](./03-microsoft-entra-id.md) you created a group to be used as a "reader" for the namespace a0008. If you want to experience this RBAC example, you'll want to add a user to that group.

If Azure RBAC is your cluster's Kubernetes RBAC backing store, then that is all that is needed.

If instead Kubernetes RBAC is backed directly by Microsoft Entra ID, then you'll need to ensure that you've updated and applied the [`rbac.yaml`](./cluster-manifests/a0008/rbac.yaml) according to the instructions found at the end of the [Microsoft Entra ID configuration page](./03-microsoft-entra-id.md).

No matter which backing store you use, the user assigned to the group will then be able to `az aks get-credentials` to the cluster and you can validate that user is limited to a *read only* view of the a0008 namespace.

## Validate Azure Policy

Built-in as well as custom policies are applied to the cluster as part of the [cluster deployment step](./06-aks-cluster.md) to ensure that workloads deployed to the cluster comply with the team's governance rules:
- Azure Policy assignments with the [*audit* effect](https://learn.microsoft.com/azure/governance/policy/concepts/effects#audit) will create a warning in the activity log and show violations in the Azure Policy blade in the portal, providing an aggregated view of the compliance state and the option to identify violating resources.
- Azure Policy assignments with the [*deny* effect](https://learn.microsoft.com/azure/governance/policy/concepts/effects#deny) will be enforced with the help of [Gatekeeper's admission controller webhook](https://open-policy-agent.github.io/gatekeeper/website/docs/) by denying API requests that would violate an Azure Policy otherwise.

:bulb: Gatekeeper policies are implemented by using the [policy language 'Rego'](https://learn.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes#policy-language). To deploy the policies in this reference architecture with the Azure platform, the Rego specification is Base64-encoded and stored in a field of the Azure Policy resource defined in `nested_K8sCustomIngressTlsHostsHaveDefinedDomainSuffix.bicep`. It might be insightful to decode the string with a Base64 decoder of your choice and investigate the declarative implementation.

### Steps

1. Try to add a second `Ingress` resource to your workload namespace with the following command.

   Notice that the host value specified in the `rules` and the `tls` sections defines a domain name with suffix `invalid-domain.com` rather than the domain suffix you defined for your setup when you [created your certificates](./02-ca-certificates.md)).

   ```bash
   cat <<EOF | kubectl create -f -
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: aspnetapp-ingress-violating
     namespace: a0008
   spec:
     tls:
     - hosts:
       - bu0001a0008-00.aks-ingress.invalid-domain.com
     rules:
     - host: bu0001a0008-00.aks-ingress.invalid-domain.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: aspnetapp-service
               port:
                 number: 80
   EOF
   ```

2. Inspect the error message and remark that Gatekeeper's admission webhook rejects `bu0001a0008-00.aks-ingress.invalid-domain.com` as incompliant host.

   ```output
   Error from server (Forbidden): error when creating "STDIN": admission webhook "validation.gatekeeper.sh" denied the request: [azurepolicy-k8scustomingresstlshostshavede-e64871e795ce3239cd99] TLS host must have one of defined domain suffixes. Valid domain names are ["contoso.com"]; defined TLS hosts are {"bu0001a0008-00.aks-ingress.invalid-domain.com"}; incompliant hosts are {"bu0001a0008-00.aks-ingress.invalid-domain.com"}.
   ```

## Validate web application firewall functionality

Your workload is placed behind a Web Application Firewall (WAF), which has rules designed to stop intentionally malicious activity. You can test this by triggering one of the built-in rules with a request that looks malicious.

> :bulb: This reference implementation enables the built-in OWASP ruleset, in **Prevention** mode.

### Steps

1. Browse to the site with the following appended to the URL: `?sql=DELETE%20FROM` (such as <https://bicycle.contoso.com/?sql=DELETE%20FROM>).
1. Observe that your request was blocked by Application Gateway's WAF rules and your workload never saw this potentially dangerous request.
1. Blocked requests (along with other gateway data) will be visible in the attached Log Analytics workspace.

   Browse to the Azure Application Gateway in the resource group `rg-bu0001-a0008` and navigate to the *Logs* blade. Execute the following query below to show WAF logs and see that the request was rejected due to a *SQL Injection Attack* (field *Message*).

   > :warning: Note that it may take a couple of minutes until the logs are transferred from the Application Gateway to the Log Analytics Workspace. So be a little patient if the query doesn't immediately return results after sending the HTTPS request in the former step.

   ```
   AzureDiagnostics
   | where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
   ```

## Validate cluster Azure Monitor insights and logs

Monitoring your cluster is critical, especially when you're running a production cluster. Therefore, your AKS cluster is configured to send [diagnostic information](https://learn.microsoft.com/azure/aks/monitor-aks) of categories *cluster-autoscaler*, *kube-controller-manager*, *kube-audit-admin* and *guard* to the Log Analytics Workspace deployed as part of the [bootstrapping step](./05-bootstrap-prep.md). Additionally, [Azure Monitor for containers](https://learn.microsoft.com/azure/azure-monitor/insights/container-insights-overview) is configured on your cluster to capture metrics and logs from your workload containers. Azure Monitor is configured to surface cluster logs, and you can see those logs as they're generated.

:bulb: If you need to inspect the behavior of the Kubernetes scheduler, enable the log category *kube-scheduler* (either through the *Diagnostic Settings* blade of your AKS cluster or by enabling the category in your `cluster-stamp.bicep` template). Note that this category is quite verbose and will increase the cost of your Log Analytics Workspace.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource.
1. Click *Insights* to see captured data.

You can also execute [queries](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-tutorial) on the [cluster logs captured](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-log-query).

1. In the Azure Portal, navigate to your AKS cluster resource.
1. Click *Logs* to see and query log data.
   :bulb: There are several examples on the *Kubernetes Services* category.

## Validate Azure Monitor for containers (Prometheus metrics)

Azure Monitor is configured to [scrape Prometheus metrics](https://learn.microsoft.com/azure/azure-monitor/insights/container-insights-prometheus-integration) in your cluster. This reference implementation is configured to collect Prometheus metrics from two namespaces, as configured in [`container-azm-ms-agentconfig.yaml`](./cluster-baseline-settings/container-azm-ms-agentconfig.yaml). There are two pods configured to emit Prometheus metrics:

- [Traefik](./workload/traefik.yaml) (in the `a0008` namespace)
- [Kured](./cluster-baseline-settings/kured.yaml) (in the `cluster-baseline-settings` namespace)

:bulb: This reference implementation ships with two queries (*All collected Prometheus information* and *Kubenertes node reboot requested*) in a Log Analytics Query Pack as an example of how you can write your own and manage them via ARM templates.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select your Log Analytic Workspace resource and open the *Logs* blade.
1. Find the one of the above queries in the *Containers* category.
1. You are able to select and execute the saved query over the scraped metrics.

## Validate workload logs

The example workload uses the standard dotnet logger interface, which are captured in `ContainerLogs` in Azure Monitor. You could also include additional logging and telemetry frameworks in your workload, such as Application Insights. Here are the steps to view the built-in application logs.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select your Log Analytic Workspace resource and open the *Logs* blade.
1. Execute the following query.

   ```
   ContainerLogV2
   | where ContainerName == "aspnet-webapp-sample"
   | project TimeGenerated, LogMessage, Computer, ContainerName, ContainerId
   | order by TimeGenerated desc
   ```

## Validate Azure Alerts

Azure will generate alerts on the health of your cluster and adjacent resources. This reference implementation sets up multiple alerts that you can subscribe to.

### Steps

An alert based on [Azure Monitor for containers information using a Kusto query](https://learn.microsoft.com/azure/azure-monitor/insights/container-insights-alerts) was configured in this reference implementation.

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select *Alerts*, then *Alert Rules*.
1. There is an alert titled "[your cluster name] Scheduled Query for Pod Failed Alert" that will be triggered based on the custom query response.

An [Azure Advisor Alert](https://learn.microsoft.com/azure/advisor/advisor-overview) was configured as well in this reference implementation.

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select *Alerts*, then *Alert Rules*.
1. There is an alert called "AllAzureAdvisorAlert" that will be triggered based on new Azure Advisor alerts.

A series of metric alerts were configured as well in this reference implementation.

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`).
1. Select your cluster, then *Insights*.
1. Select *Recommended alerts* to see those enabled. (Feel free to enable/disable as you see fit.)

## Validate Azure Container Registry image pulls

If you configured your third-party images to be pulled from your Azure Container Registry vs public registries, you can validate that the container registry logs show `Pull` logs for your cluster when you applied your flux configuration.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0008`) and then your Azure Container Registry instances (starts with `acraks`).
1. Select *Logs*.
1. Execute the following query, for whatever time range is appropriate.

   ```kusto
   ContainerRegistryRepositoryEvents
   | where OperationName == 'Pull'
   ```

1. You should see logs for kured. You'll see multiple for some as the image was pulled to multiple nodes to satisfy ReplicaSet/DaemonSet placement.

## Next step

:arrow_forward: [Clean Up Azure Resources](./12-cleanup.md)
