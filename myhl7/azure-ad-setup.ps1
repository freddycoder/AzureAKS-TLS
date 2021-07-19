param(
    [string] $name,
    [string] $replyUrl,
    [string] $logoutUrl
)

# Import helpers
. .\PSFunctions\helpers.ps1

$ErrorActionPreference = "Stop"

$app = az ad app create --display-name $name --reply-urls $replyUrl

Write-Output $app

$app = $app | ConvertFrom-Json

az ad app update --id $app.appId --set logoutUrl=$logoutUrl

Write-Output "Update done. logoutUrl set to:" $logoutUrl

Write-Output "ClientId:" $app.appId

$tenant = Get-AzTenant

Write-Output "TenantId:" $tenant.Id