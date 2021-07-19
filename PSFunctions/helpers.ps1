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
