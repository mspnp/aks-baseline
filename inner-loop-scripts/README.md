# Deploy Scripts

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline Cluster reference implementation. For more information check out the [readme file in the root](../README.md).

While this reference implementation was being developed we built out some inner-loop deployment scripts to help do rapid testing. They are included in this directory _for your reference_. They are not used as part of the [main README.md introduction/instruction](../README.md), but you can reference them for your own purposes. They may not be functional as they are maintained only opportunistically.

> NOTE: For a complete understanding, we recommend you follow the deployment steps for this Reference Implementation using the [main README.md](../README.md) steps.

In both the Shell and the .azcli files, you'll also find some "narrative comments" in there that might help you understand some of the thought process that went into this reference implementation. They are not required reading, but might shed light on some decisions made or reasoning behind a certain step.

## Shell

A Bash shell-based deployment was built for inner-loop work. This is found in the [shell directory](./shell).

> Important: you must edit these script files to be suitable for your environment and situation.

### Deploy

```bash
# [This takes thirty minutes to run.]
./shell/0-networking-stamp.sh
./shell/1-cluster-stamp.sh
```

### Clean up

```bash
# [This takes twenty minutes to run.]
./shell/deleteResourceGroups.sh
```

## .azcli files

An alternative method was capturing the steps in pure `az` cli commands, and putting them in `.azcli` files. This is found in the [azcli directory](./azcli). These files are not directly executable files (no expectation of `#!` or `+x`).  However, from Visual Studio Code, the [Azure CLI Tools extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.azurecli) provides a "right-click run" functionality. The intent was to capture the steps in a completely OS/Shell agnostic approach.

### Deploy

1. Open the [azcli directory](./azcli) in Visual Studio Code.
1. Walk through the `az` commands found in `aad-deploy.azcli`.
1. Walk through the `az` commands found in `network-deploy.azcli`, updating variables as needed.
1. Walk through the `az` commands found in `cluster-deploy.azcli`.

## Next Steps

Ultimately, as with any solution, we encourage the usage of deployment pipelines in your DevOps tooling of choice. Building scripts like these are great for initial POC/spike work, some inner-loop development work, and can often even help inform the construction of your eventual automated deployment pipelines. We did include a starter GitHub Actions workflow that covers the deployment of the cluster, which you can see in the [github-workflow directory](../github-workflow/aks-deploy.yaml).
