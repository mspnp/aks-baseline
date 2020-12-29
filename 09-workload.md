# Deploy the Workload (ASP.NET Core Docker web app)

The cluster now has an [Traefik configured with a TLS certificate](./09-secret-managment-and-ingress-controller.md). The last step in the process is to deploy the workload, which will demonstrate the system's functions.

## Steps

> :book: The Contoso app team is about to conclude this journey, but they need an app to test their new infrastructure. For this task they've picked out the venerable [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp).

1. Deploy the ASP.NET Core Docker sample web app in the AKS Cluster deployed to Region 1

   > The workload definition demonstrates the inclusion of a Pod Disruption Budget rule, ingress configuration, and pod (anti-)affinity rules for your reference.

   ```bash
   kubectl apply -f ./workload/aspnetapp.yaml --context $AKS_CLUSTER_NAME_BU0001A0042_03
   ```

1. Deploy the same workload as another instance in the second AKS cluster deployed to Region 2. Additionally, you will be enable some canary testing from the second cluster.

   > :book: The app team is now more confident than ever with its second regional AKS cluster. The team follows an active/active High Availability strategy, and it is known that the major stream of clients comes from East US 2. Therefore, they realize they have some iddle resources most of the time from Central US. This makes them to consider starting some canary testing in that specific region as this will be introducing a very low risk for the normal operatory. Using a weighted load balanced strategy, clients will be attended most of the time by their well known and stable ASP.NET Core 3.1 workload app, while others by new ASP.NET 5 aleatory. From this experimentation, the app team wants to evaluate the memory utlization of their workload using the new ASP.NET version 5. This will allow them to plan ahead before a full migration.

   > :warning: Please note that this canary testing story is not recommended for organizations that are operating critical productive systems. But this is a good example of what are the options being enabled when adding more availability to your application, and having some iddle resources to be employed with care.

   ```bash
   kubectl apply -f ./workload/aspnetapp.yaml --context $AKS_CLUSTER_NAME_BU0001A0042_04
   kubectl apply -f ./workload/aspnetapp-canary.yaml --context $AKS_CLUSTER_NAME_BU0001A0042_03
   ```

1. Wait until both regions are ready to process requests

   ```bash
   kubectl wait -n a0042 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s --context $AKS_CLUSTER_NAME_BU0001A0042_03
   kubectl wait -n a0042 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp-canary --timeout=90s --context $AKS_CLUSTER_NAME_BU0001A0042_03
   kubectl wait -n a0042 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s --context $AKS_CLUSTER_NAME_BU0001A0042_04
   kubectl wait -n a0042 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp-canary --timeout=90s --context $AKS_CLUSTER_NAME_BU0001A0042_04
   ```

1. Check the status of your Ingress resources as a way to confirm the AKS-managed Internal Load Balancer is functioning

   > In this moment your Ingress Controller (Traefik) is reading your ingress resource object configuration, updating its status, and creating a router to fulfill the new exposed workloads route. Please take a look at this and notice that the address is set with the Internal Load Balancer IP from the configured subnet.

   ```bash
   kubectl get ingress aspnetapp-ingress -n a0042 --context $AKS_CLUSTER_NAME_BU0001A0042_03
   kubectl get ingress aspnetapp-ingress -n a0042 --context $AKS_CLUSTER_NAME_BU0001A0042_04
   ```

   > At this point, the route to the workload is established, SSL offloading configured, and a network policy is in place to only allow Traefik to connect to your workload. Therefore, you should expect a `403` HTTP response if you attempt to connect to it directly.

> :book: The app team is happy to confirm to the BU0001 that their workload is now consuming less memory thanks to this update.

![The app team is doing some canary testing of their workload, just a few requests are routed to the new version. The ASP.NET 5 workload app is reporting less memory usage.](images/canary-testing.gif)

### Next step

:arrow_forward: [End to End Validation](./10-validation.md)
