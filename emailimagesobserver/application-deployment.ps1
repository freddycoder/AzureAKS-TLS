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
Write-Output "Deploy EmailImagesObserver"
Write-Output "**************************************"

$deploymentYamlPath = $PWD.Path + "\emailimagesobserver\emailimagesobserver-deployment.yaml"
$deploymentYaml = Get-Content -Path $deploymentYamlPath -Encoding UTF8 -Raw
Write-Output $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the app client-id: " "<azuread-clientid>" $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the app tenant-id: " "<azuread-tenantid>" $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the connection string: " "<sql-connectionstrings>" $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the azure vision endpoint: " "<azure-vision-endpoint>" $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the azure vision sbscription key: " "<azure-vision-substriptionkey>" $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the email used: " "<email-login>" $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the email password: " "<email-password>" $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the imap server address: " "<email-imapserver>" $deploymentYaml
$deploymentYaml = Replace-UserVariable "Enter the imap server port: " "<email-ImapPort>" $deploymentYaml

Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\emailimagesobserver-deployment.yaml", $deploymentYaml, $Utf8NoBomEncoding)

kubectl apply -f generated/emailimagesobserver-deployment.yaml -n $namespace

kubectl apply -f emailimagesobserver/emailimagesobserver-service.yaml -n $namespace

Write-Output "EmailImagesObserver deployed"

& .\emailimagesobserver\ingress-deployment.ps1 $namespace $domainPrefix $location $caName $customDomain