# Cluster Baseline Configuration Files (GitOps)

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline cluster reference implementation. For more information check out the [readme file in the root](../README.md).

This is the root of the GitOps configuration directory. These Kubernetes object files are expected to be deployed via our in-cluster Flux operator. They are our AKS cluster's baseline configurations. Generally speaking, they are workload agnostic and tend to all cluster-wide configuration concerns.

## Contents

* Default Namespaces
* Kubernetes RBAC Role Assignments (cluster and namespace) to Azure AD Groups. _Optional_
* [Kured](#kured)
* Ingress Network Policy
* Azure Monitor Prometheus Scraping
* Azure AD Pod Identity

### Kured

Kured is included as a solution to handle occasional required reboots from daily OS patching. This open-source software component is only needed if you require a managed rebooting solution between weekly [node image upgrades](https://docs.microsoft.com/azure/aks/node-image-upgrade). Building a process around deploying node image upgrades [every week](https://github.com/Azure/AKS/releases) satisfies most organizational weekly patching cadence requirements. Combined with most security patches on Linux not requiring reboots often, this leaves your cluster in a well supported state. If weekly node image upgrades satisfies your business requirements, then remove Kured from this solution by deleting [`kured.yaml`](./cluster-baseline-settings/kured.yaml). If however weekly patching using node image upgrades is not sufficient and you need to respond to daily security updates that mandate a reboot ASAP, then using a solution like Kured will help you achieve that objective. **Kured is not supported by Microsoft Support.**

## Private bootstrapping repository

Typically, your bootstrapping repository wouldn't be a public facing repository like this one, but instead a private GitHub or Azure DevOps repo. The Flux operator deployed with the cluster supports private git repositories as your bootstrapping source. In addition to requiring network line of sight to the repository from your cluster's nodes, you'll also need to ensure that you've provided the necessary credentials. This can come, typically, in the form of certificate based SSH or personal access tokens (PAT), both ideally scoped as read-only to the repo with no additional permissions.

Modify the [`cluster-stamp.json`](/cluster-stamp.json) file as follows.

### Git over SSH

Use the following pattern in your `fluxConfigurations` extension resource.

```json
{
    "type": "providers/fluxConfigurations",
    "properties": {
        "gitRepository": {
            "url": "git@github.com:yourorg/yourrepo.git"
        },
        "configurationProtectedSettings": {
            "sshPrivateKey": "<Base64 encoded PEM private key>"
        }
    }
}
```

### Git over HTTPS with personal access tokens

You'll use the following pattern in your `fluxConfigurations` extension resource.

```json
{
    "type": "providers/fluxConfigurations",
    "properties": {
        "gitRepository": {
            "url": "https://github.com/yourorg/yourrepo.git",
            "httpsUser": "<Username>"
        },
        "configurationProtectedSettings": {
            "httpsKey": "<Base64 encoded, UTF-8 encoded Personal Access Token>"
        }
    }
}
```
