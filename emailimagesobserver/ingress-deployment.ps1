param(
    [string] $namespace,
    [string] $domainPrefix,
    [string] $location,
    [string] $caName,
    [string] $customDomain
)

. .\PSFunctions\helpers.ps1

$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

Write-Output "**************************************"
Write-Output "Deploy ErabliereAPI-EmailImagesObserver Ingress"
Write-Output "**************************************"

Write-Output "Your domain prefix:" $domainPrefix
Write-Output "Your custom domain:" $customDomain
$domain = $customDomain
if ("" -eq $customDomain) {
    $domain = "$domainPrefix.$location.cloudapp.azure.com"
}

Write-Output "Create the yaml"
$templatePath = $PWD.Path + "\template\erabliereapi-emailimagesobserver-ingress.yaml"
$ingressRouteYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
$ingressRouteYaml = $ingressRouteYaml.Replace("<domain>", $domain);
$ingressRouteYaml = $ingressRouteYaml.Replace("<ca-name>", $caName);
Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\erabliereapi-emailimagesobserver-ingress.yaml", $ingressRouteYaml, $Utf8NoBomEncoding)
Write-Output "apply the yaml"
kubectl apply -f generated\erabliereapi-emailimagesobserver-ingress.yaml --namespace $namespace