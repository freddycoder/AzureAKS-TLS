param(
    [string] $namespace,
    [string] $domainPrefix,
    [string] $location,
    [string] $caName
)

# import helper functions
. .\..\PSFunctions\helpers.ps1

# Variable global a utiliser lors de la sauvegarde
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

Write-Output "******************************************************************************"
Write-Output "Deploying the apps azuredevopsteammembersvelocity in namespace $namespace."
Write-Output "******************************************************************************"

kubectl apply -f teamvelocity\redis.yaml --namespace $namespace

Write-Output "Create the azuredevopsteammembersvelocity deployment."
Write-Output "Create the yaml"
$templatePath = $PWD.Path + "\teamvelocity\" + "azuredevopsteammembersvelocity.yaml"
$appDeploymentYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
$appDeploymentYaml = Replace-UserVariable("Enter the clientid of the app", "<azuread-clientid>", $appDeploymentYaml);
$appDeploymentYaml = Replace-UserVariable("Enter the tenantid of the app", "<azuread-tenantid>", $appDeploymentYaml);
Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "azuredevopsteammembersvelocity.yaml", $appDeploymentYaml, $Utf8NoBomEncoding)
Write-Output "apply the yaml"
kubectl apply -f generated\azuredevopsteammembersvelocity.yaml --namespace $namespace

Write-Output "Create the ingress route"

Write-Output "Create the yaml"
$templatePath = $PWD.Path + "\template\" + "azuredevopsteammebersvelocity-ingress.yaml"
$ingressRouteYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
Write-Output "Your domain prefix:" $domainPrefix
$ingressRouteYaml = $ingressRouteYaml.Replace("<your-domain-prefix>", $domainPrefix);
$ingressRouteYaml = $ingressRouteYaml.Replace("<your-location>", $location);
$ingressRouteYaml = $ingressRouteYaml.Replace("<ca-name>", $caName);
Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "azuredevopsteammebersvelocity-ingress.yaml", $ingressRouteYaml, $Utf8NoBomEncoding)
Write-Output "apply the yaml"
kubectl apply -f generated\azuredevopsteammebersvelocity-ingress.yaml --namespace $namespace