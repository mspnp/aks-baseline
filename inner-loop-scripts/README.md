# Deploy Scripts

> Note: This is part of the Azure Kubernetes Service (AKS) Baseline cluster reference implementation. For more information check out the [readme file in the root](../README.md).

While this reference implementation was being developed we built out some inner-loop deployment scripts to help do rapid testing. They are included in this directory _for your reference_. They are not used as part of the [main README.md introduction/instruction](../README.md), but you can reference them for your own purposes. **They often are not functional, as they are rarely maintained.**

> NOTE: For a complete understanding, we recommend you follow the deployment steps for this Reference Implementation using the [main README.md](../README.md) steps.

In both the shell files, you'll also find some "narrative comments" in there that might help you understand some of the thought process that went into this reference implementation. They are not required reading, but might shed light on some decisions made or reasoning behind a certain step.

## Shell

A Bash shell-based deployment was built for initial inner-loop work. This is found in the [shell directory](./shell).

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

## Next Steps

Ultimately, as with any solution, we encourage the usage of deployment pipelines in your DevOps tooling of choice. Building scripts like these are great for initial POC/spike work, some inner-loop development work, and can often even help inform the construction of your eventual automated deployment pipelines. We did include a starter GitHub Actions workflow that covers the deployment of the cluster, which you can see in the [github-workflow directory](../github-workflow/aks-deploy.yaml).
