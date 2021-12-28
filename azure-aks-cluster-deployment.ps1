param(
    [string] $resourceGroup = "testcluster20211228",
    [string] $location = "eastus",
    [string] $aksClusterName = "testclusteraks20211228",
    [string] $namespace = "ingress-basic",
    [string] $dnsLabel = "testclusteraks20211228",
    [string] $appScriptPath = ".\demo\application-deployment.ps1",
    [string] $skipCertSleep = "false",
    [string] $useLetsEncryptProd = "false",
    [string] $skipDependenciesInstall = "false",
    [string] $skipLogin = "false",
    [string] $customDomain = ""
)

$ErrorActionPreference = "Stop"

# Import helpers
. .\PSFunctions\helpers.ps1

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

Write-Output "Make sure you run have a version of 'az' greater or equal than 2.29.2"

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

if ("true" -eq $skipLogin) {

} else {
    az login
}

Add-ResourceGroup $resourceGroup $location

Write-Output "Creating aksCluster with node size Standard_B2s"

Write-Host "For more info on node sizes see: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable"

Add-AKSCluster $resourceGroup $aksClusterName 2 Standard_B2s

if ("true" -eq $skipDependenciesInstall) {

} else {
    Write-Output "Installing aks cli"

    az aks install-cli
}


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
    if ("true" -eq $skipDependenciesInstall) {

    } else {
        Write-Output "Install kubernetes-helm"
        choco install kubernetes-helm
    }
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
    if ("" -eq $customDomain) {
        helm install nginx-ingress ingress-nginx/ingress-nginx --namespace $namespace --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux  --set controller.service.loadBalancerIP="$staticIP" --set controller.service.externalTrafficPolicy=Local --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$dnsLabel"
    } else {
        helm install nginx-ingress ingress-nginx/ingress-nginx --namespace $namespace --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux  --set controller.service.loadBalancerIP="$staticIP" --set controller.service.externalTrafficPolicy=Local
    }
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

if ("true" -eq $skipCertSleep) {

}
else {
    Write-Output "Wait two minutes before creating the cluster-issuer... this will prevent a request timeout to the cert-manager"
    Start-Sleep 120
}

Write-Output "Create the cluster issuer"

Write-Output "Create the yaml using email address :" $emailAddress
$templatePath = $PWD.Path + "\template\" + "cluster-issuer.yaml";
$templateClusterIssuer = Get-Content -Path $templatePath -Encoding UTF8 -Raw
$templateClusterIssuer = $templateClusterIssuer.Replace("<your-email-address>", $emailAddress);
$acmeServerUrl = "https://acme-staging-v02.api.letsencrypt.org/directory";
if ("true" -eq $useLetsEncryptProd) {
    $acmeServerUrl = "https://acme-v02.api.letsencrypt.org/directory"
}
$templateClusterIssuer = $templateClusterIssuer.Replace("<acme-server-url>", $acmeServerUrl);
$caName = "letsencrypt-staging";
if ("true" -eq $useLetsEncryptProd) {
    $caName = "letsencrypt-prod";
}
$templateClusterIssuer = $templateClusterIssuer.Replace("<ca-name>", $caName);
Write-Output "Save the yaml"
[System.IO.Directory]::CreateDirectory($PWD.Path + "\generated\")
[System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "cluster-issuer.yaml", $templateClusterIssuer, $Utf8NoBomEncoding);

Write-Output "Apply yaml"
kubectl apply -f generated/cluster-issuer.yaml --namespace $namespace

Write-Output "Now deploying your application"

& $appScriptPath $namespace $dnsLabel $location $caName $customDomain

Write-Output "Create a certificat object"

Write-Output "First look at the output to see if you need to create additional certificate"

kubectl describe certificate tls-secret --namespace $namespace

Write-Output "Do you need to create additionnal certificate ? (y/n)"

$userConfirm = Read-Host

$domain = $customDomain
if ("" -eq $customDomain) {
    $domain = "$dnsLabel.$location.cloudapp.azure.com"
}

if ($userConfirm.Trim().ToLower() -eq "y") {
    Write-Output "Create the yaml"
    $templatePath = $PWD.Path + "\template\" + "certificates.yaml";
    $ingressRouteYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
    $ingressRouteYaml = $ingressRouteYaml.Replace("<domain>", $domain);
    $ingressRouteYaml = $ingressRouteYaml.Replace("<ca-name>", $caName);
    Write-Output "saving the yaml"
    [System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "certificates.yaml", $ingressRouteYaml, $Utf8NoBomEncoding)
    Write-Output "apply the yaml"

    kubectl apply -f generated/certificates.yaml
}

Write-Output "You are all set ! You can now visit your site !"
$site1Url = "https://" + $domain
Write-Output "Url1:" $site1Url

if ($appScriptPath -eq ".\demo\application-deployment.ps1") {
    $site2Url = "https://" + $dnsLabel + "." + $location + ".cloudapp.azure.com/hello-world-two"
    Write-Output "Url2:" $site2Url
}
