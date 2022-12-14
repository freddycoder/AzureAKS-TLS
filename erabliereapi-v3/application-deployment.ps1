param(
    [string] $namespace,
    [string] $domainPrefix,
    [string] $location,
    [string] $caName,
    [string] $customDomain
)

# import helper functions
. .\PSFunctions\helpers.ps1

Write-Output "**************************************"
Write-Output "Deploy Erabliere API"
Write-Output "**************************************"

Write-Output "Your domain prefix:" $domainPrefix
Write-Output "Your custom domain:" $customDomain
$domain = $customDomain
if ("" -eq $customDomain) {
    $domain = "$domainPrefix.$location.cloudapp.azure.com"
}

Write-Output "Depoy redis"
kubectl apply -f erabliereapi-v3/redis-deployment.yaml -n $namespace

$tenantId = Get-UserVariable("Enter the tenant id use for the api azure ad: ")
$clientId = Get-UserVariable("Enter the client id use for the api: ")

$emailConfigContentPath = $PWD.Path + "\erabliereapi-v3\secrets\emailConfig.json"
$emailConfigContent = Get-Content -Path $emailConfigContentPath -Encoding UTF8 -Raw

$emailConfigContent = Replace-UserVariable "Enter the email sender: " "<emailConfig.sender>" $emailConfigContent
$emailConfigContent = Replace-UserVariable "Enter the email: " "<emailConfig.email>" $emailConfigContent
$emailConfigContent = Replace-UserSecureVariable "Enter the email password: " "<emailConfig.password>" $emailConfigContent
$emailConfigContent = Replace-UserVariable "Enter the smtp server: " "<emailConfig.smtpServer>" $emailConfigContent

$emailConfigBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($emailConfigContent))

$emailSecretPath = $PWD.Path + "\erabliereapi-v3\secrets\erabliere-api-email-alerte-config-secret.yaml"
$emailSecret = Get-Content -Path $emailSecretPath -Encoding UTF8 -Raw

$emailSecret = $emailSecret.Replace("<email-config-base64>", $emailConfigBase64)

Write-Output "Alsmote done with file generated/erabliereapi-email-secret.yaml"

Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\erabliereapi-email-secret.yaml", $emailSecret, $Utf8NoBomEncoding)
Write-Output "apply the yaml"

kubectl apply -f generated/erabliereapi-email-secret.yaml -n $namespace

Write-Output "Create the generated/erabliere-api-angular-configmap.yaml file"

$oidcContentPath = $PWD.Path + "\erabliereapi\secrets\erabliere-api-angular-configmap.yaml"
$oidcConfig = Get-Content -Path $oidcContentPath -Encoding UTF8 -Raw

$oidcConfig = $oidcConfig.Replace("<oidc.apiUrl>", "https://$domain")
$oidcConfig = Replace-UserVariable "Enter the client id use for the ui: "  "<oidc.clientId>"  $oidcConfig
$oidcConfig = $oidcConfig.Replace("<oidc.tenantId>", $tenantId)
$oidcConfig = Replace-UserVariable "Enter the scopes use for the ui: " "<oidc.scopes>" $oidcConfig
$oidcConfig = Replace-UserVariable "Enter the app root use for the ui: " "<oidc.appRoot>" $oidcConfig

Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\erabliere-api-angular-configmap.yaml", $oidcConfig, $Utf8NoBomEncoding)
Write-Output "apply the yaml"

kubectl apply -f generated/erabliere-api-angular-configmap.yaml -n $namespace

Write-Output "Create the erabliere-api-deployment yaml"
$templatePath = $PWD.Path + "\erabliereapi-v3\erabliere-api-deployment.yaml"
$delopymentYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
$delopymentYaml = $delopymentYaml.Replace("<domain>", $domain);
$delopymentYaml = $delopymentYaml.Replace("<tenant-id>", $tenantId);
$delopymentYaml = Replace-UserSecureVariable "Entrer la chaine de connexion bd: " "<sql-connexion-string>" $delopymentYaml
$delopymentYaml = $delopymentYaml.Replace("<client-id>", $clientId);
Write-Output "Enter the client id use for the swagger page: "
$swaggerclientId = Read-Host
$delopymentYaml = $delopymentYaml.Replace("<swagger-client-id>", $swaggerclientId);
Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\erabliere-api-deployment.yaml", $delopymentYaml, $Utf8NoBomEncoding)
Write-Output "apply the yaml"
kubectl apply -f generated\erabliere-api-deployment.yaml --namespace $namespace

kubectl apply -f erabliereapi/erabliere-api-service.yaml -n $namespace

Write-Output "Erabliere API deployed"

Write-Output "**************************************"
Write-Output "Deploy ErabliereApi Ingress"
Write-Output "**************************************"

Write-Output "Create the yaml"
$templatePath = $PWD.Path + "\template\erabliereapi-ingress.yaml"
$ingressRouteYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
$ingressRouteYaml = $ingressRouteYaml.Replace("<domain>", $domain);
$ingressRouteYaml = $ingressRouteYaml.Replace("<ca-name>", $caName);
Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\erabliereapi-ingress.yaml", $ingressRouteYaml, $Utf8NoBomEncoding)
Write-Output "apply the yaml"
kubectl apply -f generated\erabliereapi-ingress.yaml --namespace $namespace