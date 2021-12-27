# Workload

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline cluster reference implementation. For more information check out the [readme file in the root](../README.md).

This reference implementation is focused on the infrastructure of a secure, baseline AKS cluster. The workload is not fully in scope. However, to demonstrate the concepts and configuration presented in this AKS cluster, a workload needed to be defined.

## Web Service

The AKS cluster, in our reference implementation, is here to serve as an application platform host for a web-facing application. In this case, the ASP.NET Core Hello World application is serving as that application.

## Ingress

In this AKS cluster, we decided to do workload-level ingress. While ingress could be defined and managed at the cluster level, it's often more reasonable to define ingress as an extension of the workload. Allowing operational consistency between the workload and the ingress resource, especially in a multi-tenant AKS cluster. We are deploying Traefik as our ingress solution.
