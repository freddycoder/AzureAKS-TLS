param(
    [string] $namespace
)

Write-Output "Deploying the apps aks-helloworld and ingress-demo."

kubectl apply -f aks-helloworld.yaml --namespace $namespace
kubectl apply -f ingress-demo.yaml --namespace $namespace

Write-Output "Create the ingress route"

kubectl apply -f hello-world-ingress.yaml --namespace $namespace