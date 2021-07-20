function Add-ResourceGroup($resourceGroup, $location) {
    Write-Output "Check if resource group $resourceGroup already exists"
    $resourceGroupExists = az group exists --name $resourceGroup

    if ($resourceGroupExists -eq $false) {
        Write-Output "Create resource group $resourceGroup"

        az group create --name $resourceGroup --location $location
    } else {
        Write-Output "Skiping resource group creation. Resource group $resourceGroup already exist"
    }
}

function Add-AKSCluster($resourceGroup, $aksClusterName, $nodeCount, $nodeVMSize) {
    Write-Output "Check if AKS cluster already exist"
    $clustersInfo = az aks list | ConvertFrom-Json

    $clusterExist = $false

    foreach ($cluster in $clustersInfo) {
        if ($cluster.name -eq $aksClusterName) {
            $clusterExist = $true
        }
    }

    if ($clusterExist -eq $false) {
        az aks create --resource-group $resourceGroup --name $aksClusterName --node-count $nodeCount --node-vm-size $nodeVMSize --generate-ssh-keys
    } 
    else {
        Write-Output "Skiping AKS Cluster creation. Cluster $aksClusterName already exist"
    }
}

function Add-AzureADApplicationHelper($name, $replyUrl, $logoutUrl) {
    Write-Host "Add-AzureADApplication"
    Write-Host "1. Fetch the existing apps"
    
    $apps = az ad app list | ConvertFrom-Json

    $app = "";

    Write-Host "2. Loop througth the existing apps to find $name"
    foreach ($existingApp in $apps) {
        if ($existingApp.displayName -eq $name) {
            Write-Host "The app already exist. The app will be updated."

            $app = $existingApp
        }
    }

    if ($app -eq "") {
        Write-Host "App need to be create."

        $app = az ad app create --display-name $name --reply-urls $replyUrl

        Write-Host "App created"

        Write-Host $app

        $app = $app | ConvertFrom-Json
    }

    az ad app update --id $app.appId --reply-urls $replyUrl

    Write-Host "Update done. replyUrls set to: $replyUrl"

    az ad app update --id $app.appId --set logoutUrl=$logoutUrl

    Write-Host "Update done. logoutUrl set to: $logoutUrl"

    return $app
}