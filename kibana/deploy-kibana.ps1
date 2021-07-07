# Import helpers
. .\PSFunctions\helpers.ps1

$resourceGroupName = "kibanatest"
$clusterName = "clustbana"
$location = "eastus"

$ErrorActionPreference = "Stop"

Add-ResourceGroup $resourceGroupName $location

Add-AKSCluster $resourceGroupName $clusterName 3 Standard_B2ms

az aks get-credentials --resource-group $resourceGroupName --name $clusterName

Write-Output "**************************************"
Write-Output "Deploy Kibana"
Write-Output "**************************************"

kubectl apply -f https://download.elastic.co/downloads/eck/1.1.2/all-in-one.yaml

kubectl apply -f .\kibana\elasticsearch.yaml

kubectl get elasticsearch 
Start-Sleep 15

kubectl get pods
Start-Sleep 15

kubectl logs -f quickstart-es-default-0 
Start-Sleep 15

kubectl get service quickstart-es-http
Start-Sleep 15

PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode)

kubectl get svc quickstart-es-http

Write-Output "Enter kibana IP address, you can find it in the log of the console : "
$kibanaipaddress = Read-Host

Invoke-WebRequest -u "elastic:$PASSWORD" -k "https://$($kibanaipaddress):9200"

kubectl apply -f .\kibana\kibana.yaml

kubectl get kibana