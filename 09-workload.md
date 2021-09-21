# Deploy the Workload (ASP.NET Core Docker web app)

The cluster now has an [Traefik configured with a TLS certificate](./08-secret-management-and-ingress-controller.md). The last step in the process is to deploy the workload, which will demonstrate the system's functions.

## Steps

> :book: The Contoso app team is about to conclude this journey, but they need an app to test their new infrastructure. For this task they've picked out the venerable [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp).

1. Customize the host name of the Ingress resource to match your custom domain. _(You can skip this step if domain was left as contoso.com.)_

   ```bash
   sed -i "s/contoso.com/${DOMAIN_NAME_AKS_BASELINE}/" workload/aspnetapp-ingress-patch.yaml
   ```

1. Deploy the ASP.NET Core Docker sample web app

   > The workload definition demonstrates the inclusion of a Pod Disruption Budget rule, ingress configuration, and pod (anti-)affinity rules for your reference.

   ```bash
   kubectl apply -k workload/
   ```

1. Wait until is ready to process requests running

   ```bash
   kubectl wait -n a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s
   ```

1. Check your Ingress resource status as a way to confirm the AKS-managed Internal Load Balancer is functioning

   > In this moment your Ingress Controller (Traefik) is reading your ingress resource object configuration, updating its status, and creating a router to fulfill the new exposed workloads route. Please take a look at this and notice that the address is set with the Internal Load Balancer IP from the configured subnet.

   ```bash
   kubectl get ingress aspnetapp-ingress -n a0008
   ```

   > At this point, the route to the workload is established, SSL offloading configured, a network policy is in place to only allow Traefik to connect to your workload, and Traefik is configured to only accept requests from App Gateway.

1. Give it a try and see a `403` HTTP response from Traefik.

   > You should expect a `403` HTTP response if you attempt to connect to the ingress controller _without_ going through the App Gateway. Likewise, if any workload other than the ingress controller attempts to reach the workload, the traffic will be denied via network policies.

   ```bash
   kubectl run curl -n a0008 -i --tty --rm --image=mcr.microsoft.com/azure-cli --limits='cpu=200m,memory=128Mi'
   
   # From within the open shell now running on a container inside your cluster
   DOMAIN_NAME="contoso.com" # <-- Change to your custom domain value if a different one was used
   curl -kI https://bu0001a0008-00.aks-ingress.$DOMAIN_NAME -w '%{remote_ip}\n'
   exit
   ```

   > :beetle: You might receive a message about `--limits` being deprecated, you can [safely ignore that message](https://github.com/kubernetes/kubectl/issues/1101). Limits are still be honored; and in this deployment are required via Azure Policy for all pods running in your cluster.

   > From this container shell, you could also try to directly access the workload via `curl -I http://<aspnetapp-service-cluster-ip>`. Instead of getting back a `200 OK`, you'll receive a network timeout because of the [`allow-only-ingress-to-workload` network policy](./cluster-manifests/a0008/ingress-network-policy.yaml) that is in place.   

### Next step

:arrow_forward: [End-to-End Validation](./10-validation.md)
