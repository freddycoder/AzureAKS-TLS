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
        az aks create `
            --resource-group $resourceGroup `
            --name $aksClusterName `
            --node-count $nodeCount `
            --node-vm-size $nodeVMSize `
            --load-balancer-sku basic `
            --node-osdisk-size 32 `
            --generate-ssh-keys
    } 
    else {
        Write-Output "Skiping AKS Cluster creation. Cluster $aksClusterName already exist"
    }
}

function Add-AzureADWebApplication($name, $replyUrl, $logoutUrl) {
    Write-Host "Add-AzureADWebApplication"
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

function Add-AzureADApiApplication($name, $appUrl) {
    Write-Host "Add-AzureADApiApplication"
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

        $app = az ad app create --display-name $name

        Write-Host "App created"

        Write-Host $app

        $app = $app | ConvertFrom-Json
    }

    # Set identifier URI and define scopes
    $requeredResource = 
        @{
            resourceAppId = $appUrl
            resourceAccess = @{
                id = "a42657d6-7f20-40e3-b6f0-cee03008a62a"
                type = "Scope"
            }
        }

    Write-Host $requeredResource

    az ad app update --id $app.appId --required-resource-accesses $requeredResource

    $roleMnifest = 
        @{
            allowedMemberTypes = @(
				"User",
				"Application"
            )
			description = "fhir oss admin"
			displayName = "globalAdmin"
			isEnabled = $true
			value = "globalAdmin"
        }

    Write-Output $roleMnifest

    az ad app update --id $app.appId --app-roles $roleMnifest

    return $app
}

# Ask user for a variable and return it
function Get-UserSecureVariable($message) {
    Write-Host $message
    $secureVariable = Read-Host -AsSecureString
    return $secureVariable
}

# Ask user for a variable and return it
function Get-UserVariable($message) {
    Write-Host $message
    $variable = Read-Host
    return $variable
}

# Ask user for a variable and replace it in a string then return the string
function Replace-UserVariable([string] $message, [string] $variableName, [string] $source) {
    Write-Host $message
    $variable = Read-Host
    $string = $source.Replace($variableName, $variable)
    return $string
}

# Ask user for a secure variable and replace it in a string then return the string
function Replace-UserSecureVariable([string] $message, [string] $variableName, [string] $source) {
    Write-Host $message
    $variable = Read-Host -MaskInput
    $string = $source.Replace($variableName, $variable)
    return $string
}

