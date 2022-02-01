# Networking resource templates

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline cluster reference implementation. For more information check out the [readme file in the root](../README.md).

These files are the Bicep templates used in the deployment of this reference implementation. This reference implementation uses a standard hub-spoke model.

## Files

* [`hub-default.bicep`](./hub-default.bicep) is a file that defines a generic regional hub. All regional hubs can generally be considered a fork of this base template.
* [`hub-regionA.bicep`](./hub-regionA.bicep) is a file that defines a specific region's hub (for example, it might be named `hub-eastus2.bicep`). This is the long-lived template that defines this specific region's hub.
* [`spoke-BU0001A0008.bicep`](./spoke-BU0001A0008.bicep) is a file that defines a specific spoke in the topology. A spoke, in our narrative, is create for each workload in a business unit, hence the naming pattern in the file name.

Your organization will likely have its own standards for their hub-spoke implementation. Be sure to follow your organizational guidelines.

## Topology Details

See the [AKS Baseline Network Topology](./topology.md) for specifics on how this hub-spoke model has its subnets defined and IP space allocation concerns accounted for.

## See also

* [Hub-spoke network topology in Azure](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
