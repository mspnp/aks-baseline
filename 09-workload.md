# The ASP.NET Core Docker sample web app

Previously you have deployed an [Ingress Controller and configured its secrets](./08-secret-managment-and-ingress-controller).
This section is about to deploy a workload for testing purposes.

---

> The Contoso app team is about to conclude this journey, but they need an app to test their new infrastructure. For this task they picked out the venerable [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp). Additionally, they will include as part of the desired configuration for it some of the following concepts:
>
> * Ingress resource object
> * Network Policy to allow Ingress Controller establish connection with the app

1. Deploy the ASP.NET Core Docker sample web app

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/mspnp/reference-architectures/master/aks/secure-baseline/workload/aspnetapp.yaml
   ```

1. The ASP.NET Core Docker sample web app is all setup. Wait until is ready to process requests running:

   ```bash
   kubectl wait --namespace a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s
   ```

1. Check your Ingress resource status as a way to confirm the AKS-managed
   Internal Load Balanacer is well-configure

   > In this momment your Ingress Controller (Traefik) is reading your Ingress
   > resource object configuration, updating its status and creating a router to
   > fulfill the new exposed workloads route.
   > Please take a look at this and notice that the Address is set with the Internal Load Balancer Ip from
   > the configured subnet

   ```bash
   kubectl get ingress aspnetapp-ingress -n a0008
   ```

1. Give a try and expect a Http 403 response

   > Validate the router to the workload is configured, SSL offloading and allowing only known Ips
   > Please notice only the Azure Application Gateway is whitelisted as known client for
   > the workload's router. Therefore, please expect a Http 403 response
   > as a way to probe the router has been properly configured

   ```bash
   kubectl -n a0008 run -i --rm --tty curl --image=curlimages/curl -- sh
   curl --insecure -k -I --resolve bu0001a0008-00.aks-ingress.contoso.com:443:10.240.4.4 https://bu0001a0008-00.aks-ingress.contoso.com
   exit 0
   ```

---
Next Step: [Validation](./10-validation.md)
