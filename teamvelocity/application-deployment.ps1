param(
    [string] $namespace,
    [string] $domainPrefix,
    [string] $location
)

# Variable global a utiliser lors de la sauvegarde
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

Write-Output "******************************************************************************"
Write-Output "Deploying the apps azuredevopsteammembersvelocity in namespace $namespace."
Write-Output "******************************************************************************"

kubectl apply -f teamvelocity\azuredevopsteammembersvelocity.yaml --namespace $namespace

Write-Output "Create the ingress route"

Write-Output "Create the yaml"
$templatePath = $PWD.Path + "\template\" + "azuredevopsteammebersvelocity-ingress.yaml"
$ingressRouteYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
Write-Output "Your domain prefix:" $domainPrefix
$ingressRouteYaml = $ingressRouteYaml.Replace("<your-domain-prefix>", $domainPrefix);
$ingressRouteYaml = $ingressRouteYaml.Replace("<your-location>", $location);
Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "azuredevopsteammebersvelocity-ingress.yaml", $ingressRouteYaml, $Utf8NoBomEncoding)
Write-Output "apply the yaml"
kubectl apply -f generated\azuredevopsteammebersvelocity-ingress.yaml --namespace $namespace