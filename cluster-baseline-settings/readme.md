# Cluster Baseline Configuration Files (GitOps)

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline Cluster reference implementation. For more information check out the [readme file in the root](../README.md).

This is the root of the GitOps configuration directory. These Kubernetes object files are expected to be deployed via our in-cluster Flux operator. They are our AKS cluster's baseline configurations. Generally speaking, they are workload agnostic and tend to all cluster-wide configuration concerns.

## Contents

* Default Namespaces
* Kubernetes RBAC Role Assignments to Azure AD Principals
* Kured
* Ingress Network Policy
* Flux (self-managing)
* Azure Monitor Prometheus Scraping
* Azure KeyVault Secret Store CSI Provider
* Azure AD Pod Identity
