# Deploy the Workload (ASP.NET Core Docker web app)

The cluster now has an [Traefik configured with a TLS certificate](./09-secret-managment-and-ingress-controller.md). The last step in the process is to deploy the workload, which will demonstrate the system's functions.

## Steps

> :book: The Contoso app team is about to conclude this journey, but they need an app to test their new infrastructure. For this task they've picked out the venerable [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp).

1. Deploy the ASP.NET Core Docker sample web app

   > The workload definition demonstrates the inclusion of a Pod Disruption Budget rule, ingress configuration, and pod (anti-)affinity rules for your reference.

   ```bash
   kubectl create -f https://raw.githubusercontent.com/mspnp/aks-secure-baseline/main/workload/aspnetapp.yaml --context $AKS_CLUSTER_NAME_BU0001A0042_03
   ```

1. Wait until is ready to process requests running

   ```bash
   kubectl wait -n a0042 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s --context $AKS_CLUSTER_NAME_BU0001A0042_03
   ```

1. Check your Ingress resource status as a way to confirm the AKS-managed Internal Load Balancer is functioning

   > In this moment your Ingress Controller (Traefik) is reading your ingress resource object configuration, updating its status, and creating a router to fulfill the new exposed workloads route. Please take a look at this and notice that the address is set with the Internal Load Balancer IP from the configured subnet.

   ```bash
   kubectl get ingress aspnetapp-ingress -n a0042 --context $AKS_CLUSTER_NAME_BU0001A0042_03
   ```

   > At this point, the route to the workload is established, SSL offloading configured, and a network policy is in place to only allow Traefik to connect to your workload. Therefore, you should expect a `403` HTTP response if you attempt to connect to it directly.

1. Deploy the same workload as another instance in the second AKS cluster

   ```bash
   kubectl create -f https://raw.githubusercontent.com/mspnp/aks-secure-baseline/main/workload/aspnetapp.yaml --context $AKS_CLUSTER_NAME_BU0001A0042_04
   kubectl wait -n a0042 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s --context $AKS_CLUSTER_NAME_BU0001A0042_04
   kubectl get ingress aspnetapp-ingress -n a0042 --context $AKS_CLUSTER_NAME_BU0001A0042_04
   ```

### Next step

:arrow_forward: [End to End Validation](./11-validation.md)
