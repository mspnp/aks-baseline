# Workload

> Note: This is part of the Azure Kubernetes Service (AKS) baseline cluster reference implementation. For more information check out the [readme file in the root](../README.md).

This reference implementation is focused on the infrastructure of a secure, baseline AKS cluster. The workload is not fully in scope. However, to demonstrate the concepts and configuration presented in this AKS cluster, a workload needed to be defined.

## Web service

The AKS cluster, in our reference implementation, is here to serve as an application platform host for a web-facing application. In this case, the ASP.NET Core Hello World application is serving as that application.