# Deploy the Workload (ASP.NET Core Docker web app)

The cluster now has an [Traefik configured with a TLS certificate](./08-secret-managment-and-ingress-controller.md). The last step in the process is to deploy the workload, which will demonstrate the system's functions.

## Steps

> :book: The Contoso app team is about to conclude this journey, but they need an app to test their new infrastructure. For this task they've picked out the venerable [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp).

1. Deploy the ASP.NET Core Docker sample web app

   > The workload definition demonstrates the inclusion of a Pod Disruption Budget rule, ingress configuration, and pod (anti-)affinity rules for your reference.

   ```bash
   kubectl create -f https://raw.githubusercontent.com/mspnp/aks-secure-baseline/main/workload/aspnetapp.yaml
   ```

1. Wait until is ready to process requests running

   ```bash
   kubectl wait -n a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s
   ```

1. Deploy the Ingress resource

   ```bash
   cat <<EOF | kubectl create -f -
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: aspnetapp-ingress
     namespace: a0008
     annotations:
       kubernetes.io/ingress.allow-http: "false"
       # defines controller implementing this ingress resource: https://docs.microsoft.com/en-us/azure/dev-spaces/how-to/ingress-https-traefik
       # ingress.class annotation is being deprecated in Kubernetes 1.18: https://kubernetes.io/docs/concepts/services-networking/ingress/#deprecated-annotation
       # For backwards compatibility, when this annotation is set, precedence is given over the new field ingressClassName under spec.
       kubernetes.io/ingress.class: traefik-internal
       traefik.ingress.kubernetes.io/router.entrypoints: websecure
       traefik.ingress.kubernetes.io/router.tls: "true"
       traefik.ingress.kubernetes.io/router.tls.options: default
       traefik.ingress.kubernetes.io/router.middlewares: app-gateway-snet@file, gzip-compress@file
   spec:
     # ingressClassName: "traefik-internal"
     tls:
     - hosts:
         - bu0001a0008-00.aks-ingress.$DOMAIN_NAME
           # it is possible to opt for certificate management strategy with dedicated
           # certificates for each TLS SNI route.
           # In this Rereference Implementation for the sake of simplicity we use a
           # wildcard default certificate added at Ingress Controller configuration level which is *.example.com
           # secretName: <bu0001a0008-00-example-com-tls-secret>
     rules:
     - host: bu0001a0008-00.aks-ingress.$DOMAIN_NAME
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

1. Check your Ingress resource status as a way to confirm the AKS-managed Internal Load Balancer is functioning

   > In this moment your Ingress Controller (Traefik) is reading your ingress resource object configuration, updating its status, and creating a router to fulfill the new exposed workloads route. Please take a look at this and notice that the address is set with the Internal Load Balancer IP from the configured subnet.

   ```bash
   kubectl get ingress aspnetapp-ingress -n a0008
   ```

   > At this point, the route to the workload is established, SSL offloading configured, and a network policy is in place to only allow Traefik to connect to your workload. Therefore, you should expect a `403` HTTP response if you attempt to connect to it directly.

1. Give it a try and see a `403` HTTP response.

   ```bash
   kubectl run curl -n a0008 -i --tty --rm --image=mcr.microsoft.com/azure-cli --limits='cpu=200m,memory=128Mi'
   
   # From within the open shell
   DOMAIN_NAME="contoso.com"
   curl -kI https://bu0001a0008-00.aks-ingress.$DOMAIN_NAME -w '%{remote_ip}\n'
   exit
   ```

### Next step

:arrow_forward: [End-to-End Validation](./10-validation.md)
