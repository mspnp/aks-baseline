# End-to-End Multi Cluster Validation

Now that you have a workload deployed, the [ASP.NET Core Docker sample web app](./09-workload.md) in multiple regions, you can start validating and exploring this reference implementation of the [AKS baseline multi cluster](/README.md). In addition to the workload, there are some observability validation you can perform as well.

## Validate the Region Failover

This section will help you to validate the workload is exposed correctly and responding to HTTP requests. Additionally, the workload is now responding from multiple regions, and you want to test the failover.

### Steps

1. Get your Azure Application Gateway instance names

   ```bash
   APPGW_FQDN_BU0001A0042_03=$(az deployment group show -g rg-bu0001a0042-03 -n cluster-stamp --query properties.outputs.agwName.value -o tsv)
   APPGW_FQDN_BU0001A0042_04=$(az deployment group show -g rg-bu0001a0042-04 -n cluster-stamp --query properties.outputs.agwName.value -o tsv)
   ```

1. Get your Azure Front Door public DNS name

   > :book: the app team conducts a final system test to be sure that traffic is flowing end-to-end as expected, so they are about to place some requests against the Azure Front Door endpoint.

   ```bash
   # query the Azure Front Door FQDN
   FRONTDOOR_FQDN=$(az deployment group show -g rg-bu0001a0042-shared -n shared-svcs-stamp --query properties.outputs.fqdn.value -o tsv)
   ```

1. Add some load to the web application to test that it consistently responds `HTTP 200`; even while the system is experiencing (simulated) regional outages.

   > :book: The app team configured Azure Front Door backend pool to balance the traffic equally between the two regions. It will do a round robing between them as long as the roundtrip latency from their clients POP(s), and the two regions are the same. Otherwise, the client traffic is going to flow to a single destination which is the closest region based on the sampled latency.

   ```bash
   for i in {1..200}; do curl -I $FRONTDOOR_FQDN && sleep 10; done
   ```

   > :eyes: The above script will send one HTTP request every ten seconds to your infrastructure. The total number of HTTP requests being sent are 200.

1. Open another terminal to `Stop`/`Start` the Azure Application Gateway instances as a way to simulate total outages in both regions at different points in time as well as their recovery. Observe how your application is still responsive at any moment.

   > :book: The app team wants to run some simulations for `East US 2` and `Central US` region outages. They want to ensure both regions can failover to each other under such demanding circumstances.

   > :eyes: After executing the command below, you should immediately return to your previous terminal and observe that the web application is responding with `HTTP 200` even during the outages.

   ```bash
   # [This whole execution takes about 40 minutes.]
   az network application-gateway stop -g rg-bu0001a0042-03 -n $APPGW_FQDN_BU0001A0042_03 && \ # first incident
   az network application-gateway start -g rg-bu0001a0042-03 -n $APPGW_FQDN_BU0001A0042_03 && \
   az network application-gateway stop -g rg-bu0001a0042-04 -n $APPGW_FQDN_BU0001A0042_04 && \ # second incident
   az network application-gateway start -g rg-bu0001a0042-04 -n $APPGW_FQDN_BU0001A0042_04
   ```

   :bulb: As an important note around scalability, please take into account that after a total failover is effective, your infrastructure in the remaining region must be capable of handling 100% of the traffic. Therefore, the recommendation is to plan for this sort of event, and prepare all related backend systems to cope with it. It doesn't necessarily mean that you should purchase resources to keep them idle waiting for these very rare outages. But you want to cover every piece of infrastructure to ensure they are elastic (scalable) enough to handle that sudden increase in load. For instance [Azure Application Gateway v2 autoscaling](https://docs.microsoft.com/azure/application-gateway/application-gateway-autoscaling-zone-redundant) will kick in under these circumstances along with the Cluster Autoscaler configured as part of the [AKS Baseline](https://github.com/mspnp/aks-secure-baseline). Something else you might want to consider setting up is [Horizontal Pod Autoscaling](https://docs.microsoft.com/azure/aks/concepts-scale#horizontal-pod-autoscaler) and [Resource Quotas](https://docs.microsoft.com/en-us/azure/aks/operator-best-practices-scheduler#enforce-resource-quotas). The latter must be configured to allow up to 2X the normal capacity if you plan for full region take over. Certainly to avoid cascade failures, this will require to also contemplate out-of-cluster resources that are affected by your workload (e.g. databases, external APIs, etc.). They also must be ready to absorb as much load as you consider appropriate in your regional outage contingency plan.

## Azure Monitor Dashboard

Thanks to Azure Monitor for Containers, and several metrics exposed in this Multi Cluster solution by the rest of the involved Azure resources, you could deeply observe your infrastructure. Therefore, the recommendation is to create an easy to access Dashboard on top of the underlaying data. This should enable an organization's SRE team to take a quick glance to make sure everything is healthy, and if you find something is degraded, you can quickly navigate to inspect as well as get more insights from the resources. The idea to create a clean, organized and accessible view of your infrastructure as shown below.

The following dashboard is not shipped as part of this reference implementation but we encourage you to create your own as you see fit, based on the metrics that matter to your system.

### First incident 4:44PM UTC time, `East US 2` is in trouble

Traffic is being handled by `East US 2` as this is closest region to the client sending HTTP requests. As detailed above, Azure Front Door routes all the traffic to the fastest backend measured by their latency. It is around 4:44PM when the region outage is about to happen. Please take a look at how the `East US 2` Azure Application Gateway healthiness drops to `27%` as well as its compute units really close to `0`. It is about to go for a complete shutdown. The worst case scenario just occurred, so it is time for `Central US` to come into rescue. It is expected to lose just a few packets before it starts responding.  The architecture was designed to be highly avaialble in first place, so this incident was a transparent experience for your clients, and the traffic keeps flowing without inconveniences.

> :warning: Depending on your actual location traffic might flow different for you. But having two simulated incidents ensures that you experience at least one failover.

![Azure Monitor Dashboard that helps to observe the `East US 2` region outage simulation and how the traffic flowed from `East US 2` to `Central US`](images/azure-monitor-dashboard-1st-failover.png)

> Note: from the Inbound Multi Cluster Traffic Flow Count and Azure AppFw Health Dashboaard Metrics: :large_blue_circle: East US 2 :red_circle: Central US

### Second incident 4:56PM UTC time, `East US 2` resumed its operations but `Central US` is about to go down as well

Now `East US 2` region is back after a ~12 minutes outage. Every 30 seconds, Azure Front Door samples the roundtrip latencies against its backend pools using the configured health probe, and once again determines `East US 2` is the best candidate as this normalized its operations. Traffic starts flowing at 4:56PM the other way around from `Central US` to `East US 2`, and now everything is back to normal. At the same time, you can observe a new outage, same symptoms as before, but it is now in `Central US` where the compute units are close to `0` and healthiness is about to drop to `0%` a few seconds after. It does not represent a threat since just a moment ago traffic had already flowed to `East US 2`. Around 5:15PM all regions are operative, and the clients never suffered the consequences of these multiple total region outages.

![Azure Monitor Dashboard that helps to observe the `Central US` stops serving in favor of `East US 2` region as this is back from first incident. It displays the traffic flowing now the other way around from `Central US` to `East US 2`](images/azure-monitor-dashboard-back-to-normal.png)

> Note: from the Inbound Multi Cluster Traffic Flow Count and Azure AppFw Health Dashboaard Metrics: :large_blue_circle: East US 2 :red_circle: Central US

## Validate Centralized Azure Log Analitycs workspace logs

See the centralized logs associated to each cluster, which are captured in `ContainerLogs` in Azure Monitor. In the case of your workload, you could also include additional logging and telemetry frameworks, such as Application Insights. Here are the steps to view the built-in application logs.

### Steps

1. In the Azure Portal, navigate to your AKS cluster resource group (`rg-bu0001a0042-shared`).
1. Select your Log Analytic Workspace resource.
1. Navigate under General and click Logs. Then execute the following query

   ```
   let podInventory = KubePodInventory
   | distinct ContainerID, ContainerName, ClusterId, ClusterName
   | project-rename Name=ContainerName;
   ContainerLog
   | project-away Name
   | join kind=inner
       podInventory
   on ContainerID
   | project TimeGenerated, LogEntry, Computer, Name=strcat(ClusterName, "/", Name), ContainerID
   | order by TimeGenerated desc
   ```

## Next step

:arrow_forward: [Clean Up Azure Resources](./11-cleanup.md)
