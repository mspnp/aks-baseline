# Deploy the workload (ASP.NET Core Docker web app)

The customer now has its [prerequisite components](./08-workload-prerequisites.md), including the Gateway resource and TLS certificate sync. The last step in the process is to deploy the workload, which will demonstrate the system's functions.

## Steps

> :book: The Contoso workload team is about to conclude this journey, but they need an app to test their new infrastructure. For this task they've picked out the venerable [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/main/samples/aspnetapp).

1. Customize the host name of the HTTPRoute resource to match your custom domain. *(You can skip this step if domain was left as contoso.com.)*

   ```bash
   sed -i "s/contoso.com/${DOMAIN_NAME_AKS_BASELINE}/" workload/02-aspnetapp-httproute.yaml
   ```

   Note, that if you are on macOS, you might need to use the following command instead:

   ```bash
   sed -i '' 's/contoso.com/'"${DOMAIN_NAME_AKS_BASELINE}"'/g' workload/02-aspnetapp-httproute.yaml
   ```

1. Deploy the ASP.NET Core Docker sample web app

   > The workload definition demonstrates the inclusion of a Pod Disruption Budget rule, HTTPRoute configuration, and pod (anti-) affinity rules for your reference.

   ```bash
   kubectl apply -k workload/
   ```

1. Wait until is ready to process requests running

   ```bash
   kubectl wait -n a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s
   ```

1. Check your Gateway resource status as a way to confirm the AKS-managed Internal Load Balancer is functioning

   > The gateway controller has reconciled the Gateway resource, provisioned an Envoy proxy, and created an internal load balancer on the configured subnet. Verify the Gateway is programmed and has an address assigned.

   ```bash
   kubectl get gateway bu0001a0008-gateway -n a0008
   ```

   > At this point, the route to the workload is established, TLS termination is configured on the gateway proxy, and network policies are in place to only allow the Envoy proxy to connect to your workload and to only allow traffic from the Application Gateway subnet to reach the gateway proxy.

1. Create the DNS A record for the gateway proxy internal load balancer.

   > :warning: The application routing add-on's external-dns component currently uses `--source=ingress` and does not watch Gateway API resources. Until `--source=gateway-httproute` support is added, you must manually create DNS records that map your ingress hostname to the gateway proxy's internal load balancer IP address. This step will be removed once the add-on supports automatic DNS record management for Gateway API resources.

   ```bash
   GATEWAY_IP=$(kubectl get gateway bu0001a0008-gateway -n a0008 -o jsonpath='{.status.addresses[0].value}')
   az network private-dns record-set a add-record -g rg-enterprise-networking-spokes -z "aks-ingress.${DOMAIN_NAME_AKS_BASELINE}" -n bu0001a0008-00 -a $GATEWAY_IP
   ```

1. Check the HTTPRoute is accepted by the Gateway

   ```bash
   kubectl get httproute aspnetapp-route -n a0008 -o jsonpath='{range .status.parents[*]}{.controllerName}{"\t"}{.conditions[*].type}={.conditions[*].status}{"\n"}{end}'
   ```

1. Test direct workload access from unauthorized network locations. *Optional.*

   > You should expect a timeout if you attempt to connect directly to the workload *without* going through the gateway proxy. The NetworkPolicy restricts ingress to the workload pods to only accept traffic from the Envoy gateway proxy. Likewise, a NetworkPolicy on the gateway proxy restricts its ingress to only the Application Gateway subnet and cluster nodes.

   ```bash
   kubectl run curl -n a0008 -i --tty --rm --image=mcr.microsoft.com/devcontainers/base --overrides='[{"op":"add","path":"/spec/containers/0/resources","value":{"limits":{"cpu":"200m","memory":"128Mi"}}},{"op":"add","path":"/spec/containers/0/securityContext","value":{"readOnlyRootFilesystem": true}}]' --override-type json --env="DOMAIN_NAME=${DOMAIN_NAME_AKS_BASELINE}"

   # From within the open shell now running on a container inside your cluster
   curl -kI https://bu0001a0008-00.aks-ingress.$DOMAIN_NAME -w '%{remote_ip}\n' --connect-timeout 5
   exit
   ```

   > From this container shell, you could also try to directly access the workload via:
   > - `curl -I http://aspnetapp-service --connect-timeout 5`. This request should timeout since a network policy only allows the Envoy gateway proxy to reach your application.

1. Because you've finished managing your cluster, close the Azure Bastion tunnel:

   ```bash
   exit
   ```

   > You can re-open an Azure Bastion tunnel later when you require access to the AKS private cluster's API server.

### Next step

:arrow_forward: [End-to-End Validation](./10-validation.md)
