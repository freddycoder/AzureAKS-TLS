# AzureAKS-TLS
A repo with scripts to deploy a AKS cluster with ingress using TLS with auto cert renew.

## Work in progress.

Right now the script deploy the cluster, setup static IP, and create the ingress controller. 

## TODO

- Create cluster-issuer
- Create cert-issuer
- Deploy the app
- Validate auto-renew is working

### Run the script

1. Change the email in the cluster-issuer.yaml for one of yours
2. Run the script ```azure-aks-cluster-deployment.ps1``` as administrator

To cleanup the resrouce, you can run ```cleanup-resource.ps1```.

### Dependancies

Chocolaty
Kubectl
Azure Cli
