You can choose to deploy the Secure AKS cluster baseline by executing the following script files.

> Tip: we recommend to deploy this Reference Implementation using the README.md
> steps, but please feel free to use this deployment path if you find
> this more convinient

### Deploy

> Important: edit these script files to complete the required values before procedding

```bash
# [This takes thirty minutes to run.]
./0-networking-stamp.sh && \
./1-cluster-stamp.sh`

### Clean up

```bash
# [This takes twenty minutes to run.]
./deleteResourceGroups.sh
```
