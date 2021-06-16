param(
    [string] $resourceGroup = "erabliereapi",
    [string] $location = "eastus",
    [string] $aksClusterName = "kerabliere",
    [string] $namespace = "ingress-basic",
    [string] $dnsLabel = "erabliereapidemo1"
)

$ErrorActionPreference = "Stop"

Write-Output "Azure AKS Cluster deployment"
Write-Output ""
Write-Output "Documentation that help writing this script"
Write-Output "Create resource group   : https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-prepare-acr?tabs=azure-cli"
Write-Output "Create AKS Cluster      : https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-deploy-cluster?tabs=azure-cli"
Write-Output "Setup TLS Ready Ingress : https://docs.microsoft.com/en-us/azure/aks/ingress-static-ip"
Write-Output ""

az --version

Write-Output "Make sure you run have a version greater than 2.0.53"

Write-Output "Do you want to procced ? (y/n)"

$userConfirm = Read-Host

if ($userConfirm.Trim().ToLower() -eq 'n') {
    Write-Output "Operation canceled"
    exit 0
}

Write-Output "Login to azure"

az login

Write-Output "Check if resource group already exists"
$resourceGroupExists = az group exists --name erabliereapi

if ($resourceGroupExists -eq $false) {
    Write-Output "Create resource group"

    az group create --name $resourceGroup --location $location
} else {
    Write-Output "Skiping resource group creation. Resource group $resourceGroup already exist"
}

Write-Output "Check if AKS cluster already exist"
$clustersInfo = az aks list | ConvertFrom-Json

$clusterExist = $false

foreach ($cluster in $clustersInfo) {
    if ($cluster.name -eq $aksClusterName) {
        $clusterExist = $true
    }
}

if ($clusterExist -eq $false) {
    Write-Output "Creating aksCluster"

    az aks create --resource-group $resourceGroup --name $aksClusterName --node-count 2 --generate-ssh-keys
} else {
    Write-Output "Skiping AKS Cluster creation. Cluster $aksClusterName already exist"
}

Write-Output "Installing aks cli"

az aks install-cli

Write-Output "Getting AKS credentials"

az aks get-credentials --resource-group $resourceGroup --name $aksClusterName

Write-Output "Setting static public IP address"

az aks show --resource-group $resourceGroup --name $aksClusterName --query nodeResourceGroup -o tsv

$ipResourceGroup = "MC_" + $resourceGroup + "_" + $aksClusterName + "_" + $location;
$ipName = $aksClusterName + "PublicIp";

Write-Output "Check if static public IP address already exist"

$ipList = az network public-ip list | ConvertFrom-Json

$ipExist = $false

$ipInfo = {}

foreach ($ipEntity in $ipList) {
    if ($ipEntity.resourceGroup -eq $ipResourceGroup -and $ipEntity.name -eq $ipName) {
        $ipExist = $true
        $ipInfo = $ipEntity
    }
}

if ($ipExist -eq $false) {
    $ipInfo = az network public-ip create --resource-group $ipResourceGroup --name $ipName --sku Standard --allocation-method static --query publicIp.ipAddress -o tsv

    $staticIP = $ipInfo.Split("\n")[1];
} else {
    Write-Output "Skipping static public IP address. IP $ipName already exist"

    $staticIP = $ipInfo.ipAddress;
}

kubectl create namespace $namespace

Write-Output "Install kubernetes-helm"
choco install kubernetes-helm

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

$ingressControllerExist = $false

$deployments = kubectl get deployment -n $namespace

foreach ($deployment in $deployments) {
    if ($deployment.Contains("nginx-ingress-ingress-nginx-controller")) {
        $ingressControllerExist = $true
    }
}

if ($ingressControllerExist -eq $false) {
    helm install nginx-ingress ingress-nginx/ingress-nginx --namespace $namespace --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux  --set controller.service.loadBalancerIP="$staticIP" --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$dnsLabel"
} else {
    Write-Output "Skipping Ingress Controller Deployment. Deployment nginx-ingress-ingress-nginx-controller already exist"
}

Write-Output "Verify ip network settings"

Start-Sleep 10

kubectl --namespace $namespace get services -o wide nginx-ingress-ingress-nginx-controller

az network public-ip list --resource-group $ipResourceGroup --query "[?name=='$ipName'].[dnsSettings.fqdn]" -o tsv

Write-Output "Installing CertManager"

Write-Output "Label the cert-manager namespace to disable resource validation"
kubectl label namespace $namespace cert-manager.io/disable-validation=true

Write-Output "Add the Jetstack Helm repository"
helm repo add jetstack https://charts.jetstack.io

Write-Output "Update your local Helm chart repository cache"
helm repo update

Write-Output "Install the cert-manager Helm chart"
helm install cert-manager --namespace $namespace --version v1.3.1 --set installCRDs=true --set nodeSelector."beta\.kubernetes\.io/os"=linux jetstack/cert-manager

Write-Output "Create the cluster issuer"
kubectl apply -f cluster-issuer.yaml --namespace $namespace

