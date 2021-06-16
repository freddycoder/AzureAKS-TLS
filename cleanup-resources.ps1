# Azure AKS Cluster cleanup
param(
    [string] $resourceGroup = "erabliereapi",
    [string] $location = "eastus",
    [string] $aksClusterName = "kerabliere",
    [string] $namespace = "ingress-basic",
    [string] $dnsLabel = "erabliereapidemo1"
)

$ErrorActionPreference = "Stop"

kubectl delete -f generated\cluster-issuer.yaml -n $namespace

helm list --all-namespaces

helm uninstall nginx-ingress cert-manager -n $namespace

kubectl delete -f generated\aks-helloworld.yaml -n $namespace
kubectl delete -f generated\ingress-demo.yaml -n $namespace

kubectl delete namespace $namespace

$ipResourceGroup = "MC_" + $resourceGroup + "_" + $aksClusterName + "_" + $location
$ipName = $aksClusterName + "PublicIp";

Write-Output "Deleting public static ip"
az network public-ip delete --resource-group $ipResourceGroup --name $ipName
Write-Output "IP deleted"
Write-Output ""
Write-Output "Cleanup resource done !"