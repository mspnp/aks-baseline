# Cluster baseline configuration files (GitOps)

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline cluster reference implementation. For more information check out the [readme file in the root](../README.md).

This is the root of the GitOps configuration directory. These Kubernetes object files are expected to be deployed via our in-cluster Flux operator. They are our AKS cluster's baseline configurations. Generally speaking, they are workload agnostic and tend to all cluster-wide configuration concerns.

## Contents

- Default Namespaces
- Kubernetes RBAC Role Assignments (cluster and namespace) to Microsoft Entra groups. *Optional*
- Ingress Network Policy
- Azure Monitor Prometheus Scraping

## Private bootstrapping repository

Typically, your bootstrapping repository wouldn't be a public-facing repository like this one, but instead a private GitHub or Azure DevOps repo. The Flux operator deployed with the cluster supports private Git repositories as your bootstrapping source. In addition to requiring network line of sight to the repository from your cluster's nodes, you'll also need to ensure that you've provided the necessary credentials. This can come, typically, in the form of certificate-based SSH or personal access tokens (PAT), both ideally scoped as read-only to the repo with no additional permissions.

Modify the [`cluster-stamp.bicep`](../workload-team/cluster-stamp.bicep) file as follows.

### Git over SSH

Use the following pattern in your `fluxConfigurations` extension resource.

```bicep
resource mc_fluxConfiguration 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
  // ... Other properties here
  properties: {
    // ... Other properties here
    gitRepository: {
      url: 'git@github.com:yourorg/yourrepo.git'
    }
    configurationProtectedSettings: {
      sshPrivateKey: '<Base64 encoded PEM private key>'
    }
  }
}
```

### Git over HTTPS with personal access tokens

You'll use the following pattern in your `fluxConfigurations` extension resource.

```bicep
resource mc_fluxConfiguration 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
  // ... Other properties here
  properties: {
    // ... Other properties here
    gitRepository: {
      url: 'https://github.com/yourorg/yourrepo.git'
      httpsUser: '<Username>'
    }
    configurationProtectedSettings: {
      httpsKey: '<Base64 encoded, UTF-8 encoded Personal Access Token>'
    }
  }
}
```
