param(
    [string] $namespace,
    [string] $domainPrefix,
    [string] $location,
    [string] $caName
)

Write-Output "**************************************"
Write-Output "Deploy Fhir Api"
Write-Output "**************************************"
Write-Output ""
Write-Output "AzureAD setup..."

# $api = Add-AzureADApiApplication FhirApi-Prod "https://$domainPrefix.$location.cloudapp.azure.com/api"

$app = Add-AzureADWebApplication BlazorOnFhir-Prod "https://$domainPrefix.$location.cloudapp.azure.com/signin-oidc" "https://$domainPrefix.$location.cloudapp.azure.com/signout-oidc"
Write-Output "ClientId:" $app.appId
$tenant = Get-AzTenant
Write-Output "TenantId:" $tenant.Id

Write-Output ""
Write-Output ""
Write-Output "Kubernetes setup..."

$secrets = kubectl get secret -n $namespace

$secretMssqlExist = $false;

foreach ($secret in $secrets) {
    if ($secret.StartsWith("mssql ")) {
        $secretMssqlExist = $true;
    }
}

if ($false -eq $secretMssqlExist) {
    kubectl create secret generic mssql --from-literal=SA_PASSWORD="V3ryStr0ngPa55!" --namespace=$namespace
}

kubectl apply -f .\myhl7\fhir-api-storage.yaml --namespace=$namespace

kubectl apply -f .\myhl7\fhir-db-deployment.yaml --namespace=$namespace

kubectl apply -f .\myhl7\fhir-db-service.yaml --namespace=$namespace

kubectl apply -f .\myhl7\fhir-api-deployment.yaml --namespace=$namespace

kubectl apply -f .\myhl7\fhir-api-service.yaml --namespace=$namespace

$blazorOnFhirYamlPath = $PWD.Path + "\myhl7\blazoronfhir-deployment.yaml"
$blazorOnYaml = Get-Content -Path $blazorOnFhirYamlPath -Encoding UTF8 -Raw
$blazorOnYaml = $blazorOnYaml.Replace("<client-id>", $app.appId)
$blazorOnYaml = $blazorOnYaml.Replace("<tenant-id>", $tenant.Id)
Write-Output $blazorOnYaml
$blazorOnYaml | kubectl apply --namespace=$namespace -f -

kubectl apply -f .\myhl7\blazoronfhir-service.yaml --namespace=$namespace

Write-Output "**************************************"
Write-Output "Deploy Fhir Api Ingress"
Write-Output "**************************************"

Write-Output "Create the yaml"
$templatePath = $PWD.Path + "\template\" + "fhir-api-ingress.yaml"
$ingressRouteYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
Write-Output "Your domain prefix:" $domainPrefix
$ingressRouteYaml = $ingressRouteYaml.Replace("<your-domain-prefix>", $domainPrefix);
$ingressRouteYaml = $ingressRouteYaml.Replace("<your-location>", $location);
$ingressRouteYaml = $ingressRouteYaml.Replace("<ca-name>", $caName);
Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "fhir-api-ingress.yaml", $ingressRouteYaml, $Utf8NoBomEncoding)
Write-Output "apply the yaml"
kubectl apply -f generated\fhir-api-ingress.yaml --namespace $namespace