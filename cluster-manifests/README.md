# Cluster Baseline Configuration Files (GitOps)

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline Cluster reference implementation. For more information check out the [readme file in the root](../README.md).

This is the root of the GitOps configuration directory. These Kubernetes object files are expected to be deployed via our in-cluster Flux operator. They are our AKS cluster's baseline configurations. Generally speaking, they are workload agnostic and tend to all cluster-wide configuration concerns.

## Contents

* Default Namespaces
* Kubernetes RBAC Role Assignments (cluster and namespace) to Azure AD Groups. _Optional_
* [Kured](#kured)
* Ingress Network Policy
* Flux (self-managing)
* Azure Monitor Prometheus Scraping
* Azure KeyVault Secret Store CSI Provider
* Azure AD Pod Identity

### Kured

Kured is included as a solution to handle occasional required reboots from daily OS patching. This open-source software component is only needed if you require a managed rebooting solution between weekly [node image upgrades](https://docs.microsoft.com/azure/aks/node-image-upgrade). Building a process around deploying node image upgrades [every week](https://github.com/Azure/AKS/releases) satisfies most organizational weekly patching cadence requirements. Combined with most security patches on Linux not requiring reboots often, this leaves your cluster in a well supported state. If weekly node image upgrades satisfies your business requirements, then remove Kured from this solution by deleting [`kured.yaml`](./cluster-baseline-settings/kured.yaml). If however weekly patching using node image upgrades is not sufficient and you need to respond to daily security updates that mandate a reboot ASAP, then using a solution like Kured will help you achieve that objective. **Kured is not supported by Microsoft Support.**
