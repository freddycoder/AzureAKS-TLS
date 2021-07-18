param(
    [string] $namespace,
    [string] $domainPrefix,
    [string] $location,
    [string] $caName
)

# Variable global a utiliser lors de la sauvegarde
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

Write-Output "Deploying the apps aks-helloworld and ingress-demo."

kubectl apply -f demo\aks-helloworld.yaml --namespace $namespace
kubectl apply -f demo\ingress-demo.yaml --namespace $namespace

Write-Output "Create the ingress route"

Write-Output "Create the yaml"
$templatePath = $PWD.Path + "\template\" + "hello-world-ingress.yaml"
$ingressRouteYaml = Get-Content -Path $templatePath -Encoding UTF8 -Raw
Write-Output "Your domain prefix:" $domainPrefix
$ingressRouteYaml = $ingressRouteYaml.Replace("<your-domain-prefix>", $domainPrefix);
$ingressRouteYaml = $ingressRouteYaml.Replace("<your-location>", $location);
$ingressRouteYaml = $ingressRouteYaml.Replace("<ca-name>", $caName);
Write-Output "saving the yaml"
[System.IO.File]::WriteAllText($PWD.Path + "\generated\" + "hello-world-ingress.yaml", $ingressRouteYaml, $Utf8NoBomEncoding)
Write-Output "apply the yaml"
kubectl apply -f generated\hello-world-ingress.yaml --namespace $namespace