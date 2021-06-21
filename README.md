# AzureAKS-TLS
A repo with scripts to deploy a AKS cluster with ingress using TLS with auto cert renew.

## Run the script

Before running the script, I suggest you check the parameters and changes values for those you want.

With a powershell console place inside this repo. Execute 

```
.\azure-aks-cluster-deployment.ps1
```

You will be ask a few questions along the process and the execution will take something like 4 minutes.

Once your done. You can cleanup resource created be the script.

```
.\cleanup-resources.ps1
```

The AKS Cluster and the resource group are not automaticly deleted. You will need to delete them manually if you don't want to keep them. 

### What to do if there is an error

If for some reson there is an error during the execution of the script cause by extarnal factor. After fixing the issue, you can restart the script and neccessary check 
are going to be verify the not duplicate or create other new resource.

### Dependancies

- Chocolaty
- Kubectl
- Azure Cli
- Powershell
- Windows
