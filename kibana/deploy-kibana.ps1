# Import helpers
. .\PSFunctions\helpers.ps1

$resourceGroupName = "kibanatest"
$clusterName = "clustbana"
$location = "eastus"

# Source:
# https://www.elastic.co/blog/how-to-run-elastic-cloud-on-kubernetes-from-azure-kubernetes-service
# https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-installation-configuration.html

# https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable

$ErrorActionPreference = "Stop"

az login

Add-ResourceGroup $resourceGroupName $location

Add-AKSCluster $resourceGroupName $clusterName 3 Standard_B2ms

az aks get-credentials --resource-group $resourceGroupName --name $clusterName

Write-Output "**************************************"
Write-Output "Deploy Kibana"
Write-Output "**************************************"

kubectl apply -f https://download.elastic.co/downloads/eck/1.1.2/all-in-one.yaml

kubectl apply -f .\kibana\elasticsearch.yaml

Start-Sleep 20
kubectl get elasticsearch 

Start-Sleep 20
kubectl get pods

Start-Sleep 20
kubectl logs -f quickstart-es-default-0 

Start-Sleep 20
kubectl get service quickstart-es-http

$PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o=jsonpath='{.data.elastic}')
$PASSWORD=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PASSWORD))

kubectl get svc quickstart-es-http

Write-Output "Enter kibana IP address, you can find it in the log of the console : "
$kibanaipaddress = Read-Host

Write-Output $kibanaipaddress
Write-Output $PASSWORD
Write-Output "Invoke-WebRequest -ProxyCredential ""elastic:$PASSWORD"" -Proxy ""https://$($kibanaipaddress):9200"""

kubectl apply -f .\kibana\kibana.yaml

kubectl get kibana

$vmAdminUser = "kibanaadmin"
$vmName = "myVM"

az vm create --resource-group $resourceGroupName --name $vmName --image UbuntuLTS --admin-username $vmAdminUser --generate-ssh-keys

# ssh $vmAdminUser@<vm-public-ip>

# wget https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-7.9.2-amd64.deb

# sudo dpkg -i metricbeat-7.9.2-amd64.deb

# sudo nano /etc/metricbeat/metricbeat.yml

# sudo nano /etc/metricbeat/modules.d/azure.yml.disabled

# Create the application in Azure AD and add a client secret

# cd /usr/bin

# sudo ./metricbeat modules enable azure

# sudo ./metricbeat setup --dashboards # ssl error...

# sudo ./metric