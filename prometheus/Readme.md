### Deploy base monitoring stack using HELM

```
# Define public Kubernetes chart repository in the Helm configuration
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update local repositories
helm repo update

# Search for newly installed repositories
helm repo list

# Create a namespace for Prometheus and Grafana resources
kubectl create ns prometheus

# Install Prometheus using HELM
helm install prometheus prometheus-community/kube-prometheus-stack -n prometheus

# Check all resources in Prometheus Namespace
kubectl get all -n prometheus
```

### Update the Prometheus helm release
```
helm upgrade prometheus prometheus-community/kube-prometheus-stack -n prometheus -f values.yaml
```