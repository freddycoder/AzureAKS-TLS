# erabliereapi-v3

This folder containes files to deploy the version 3 of the ErabiereAPI projet.

## Run the script

From the root folder of the repository, execute the following command:

```powershell
.\azure-aks-cluster-deployment.ps1 -resourceGroup erabliereapiv3 -location canadaeast -aksClusterName kerabliereapiv3 -namespace erabliereapi-prod -appScriptPath .\erabliereapi-v3\application-deployment.ps1 -useLetsEncryptProd true -customDomain erabliereapi.freddycoder.com
```

