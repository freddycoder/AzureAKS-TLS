param(
    [string] $resourceGroup = "erabliereapi",
    [string] $location = "eastus",
    [string] $aksClusterName = "kerabliere",
    [string] $namespace = "ingress-basic",
    [string] $dnsLabel = "erabliereapidemo1",
    [string] $appScriptPath = ".\demo\application-deployment.ps1"
)

$ErrorActionPreference = "Stop"

# Variable global a utiliser lors de la sauvegarde
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

Write-Output "Azure AKS Cluster deployment"
Write-Output ""
Write-Output "Documentation that help writing this script"
Write-Output "Create resource group   : https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-prepare-acr?tabs=azure-cli"
Write-Output "Create AKS Cluster      : https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-deploy-cluster?tabs=azure-cli"
Write-Output "Setup TLS Ready Ingress : https://docs.microsoft.com/en-us/azure/aks/ingress-static-ip"
Write-Output ""

az --version

Write-Output "Make sure you run have a version of 'az' greater than 2.0.53"

Write-Output "Do you want to procced ? (y/n)"

$userConfirm = Read-Host

if ($userConfirm.Trim().ToLower() -eq 'n') {
    Write-Output "Operation canceled"
    exit 0
}

Write-Output "To correclty configure the cluster-isser, you need to enter an valid email address."
Write-Output "Email : "

$emailAddress = Read-Host

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
    Write-Output "Creating aksCluster with node size Standard_B2s"

    Write-Host "For more info on node sizes see: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable"

    az aks create --resource-group $resourceGroup --name $aksClusterName --node-count 2 --node-vm-size Standard_B2s --generate-ssh-keys
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

try {
    Write-Output "Install kubernetes-helm"
    choco install kubernetes-helm
} catch {
    Write-Output "Choco install kebernetes-helm failed... you may need to install helm manually"
}


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

Write-Output "Wait two minutes before creating the cluster-issuer... this will prevent a request timeout to the cert-manager"
Start-Sleep 120

Write-Output "Create the cluster issuer"

Write-Output "Create the yaml using email address :" $emailAddress
$templatePath = $PWD.Path + "\template\" + "cluster-issuer.yaml";
$templateClusterIssuer = Get-Content -Path $templatePath -Encoding UTF8 -Raw
$templateClusterIssuer = $templateClusterIssuer.Replace("<your-email-address>", $emailAddress);
Write-Output "Save the yaml"
[System.IO.Directory]::CreateDirectory($PWD.Path + "\generated\")
[System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "cluster-issuer.yaml", $templateClusterIssuer, $Utf8NoBomEncoding);

Write-Output "Apply yaml"
kubectl apply -f generated/cluster-issuer.yaml --namespace $namespace

Write-Output "Now deploying your application"

& $appScriptPath $namespace $dnsLabel $location

Write-Output "Create a certificat object"

Write-Output "First look at the output to see if you need to create additional certificate"

kubectl describe certificate tls-secret --namespace $namespace

Write-Output "Do you need to create additionnal certificate ? (y/n)"

$userConfirm = Read-Host

if ($userConfirm.Trim().ToLower() -eq "y") {
    Write-Output "Create the yaml"
    $templatePath = $PWD.Path + "\template\" + "certificates.yaml";
    $ingressRouteYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
    $ingressRouteYaml = $ingressRouteYaml.Replace("<your-domain-prefix>", $dnsLabel);
    $ingressRouteYaml = $ingressRouteYaml.Replace("<your-location>", $location);
    Write-Output "saving the yaml"
    [System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "certificates.yaml", $ingressRouteYaml, $Utf8NoBomEncoding)
    Write-Output "apply the yaml"

    kubectl apply -f generated/certificates.yaml
}

Write-Output "You are all set ! You can now visit your site !"
$site1Url = "https://" + $dnsLabel + "." + $location + ".cloudapp.azure.com"
$site2Url = "https://" + $dnsLabel + "." + $location + ".cloudapp.azure.com/hello-world-two"
Write-Output "Url1:" $site1Url
Write-Output "Url2:" $site2Url