# GitHub Actions Workflow

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline Cluster reference implementation. For more information check out the [readme file in the root](../README.md).

This cluster, as with any workload, should be managed via an automated deployment pipeline. In this reference implementation we provide a "getting started" GitHub Action workflow file that you can reference to build your own.

## Steps

This workflow file deploys the cluster into an already-existing virtual network and AAD configuration as set up by the steps in the [main README.md file](../README.md).

## Secrets

Secrets should not be stored in this file, but instead should be stored as part of the secret store of GitHub Actions.

## Workload

The workload is NOT part of this deployment.  This is a deployment of the infrastructure only.  Separation of infrastructure and workload is recommended as it allows you to have distinct lifecycle and operational concerns.

## Next Steps

Review the yaml file to see the types of steps you'd need to perform. Also consider your workflow as a mechanism to deploy to another region in case of a regional failure, the pipeline should be built in such a way that with parameter/input alterations, you can deploy a new cluster in a new region.

## See also

* [GitHub Actions](https://help.github.com/actions)
* [GitHub Actions with Azure Kubernetes Service](https://docs.microsoft.com/azure/aks/kubernetes-action)