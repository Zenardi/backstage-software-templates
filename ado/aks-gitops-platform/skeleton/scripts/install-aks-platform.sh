#!/usr/bin/env bash
# install-aks-platform.sh — Install all platform tools on the newly provisioned AKS cluster.
#
# Required environment variables:
#   AKS_NAME              — AKS cluster name (e.g. aks-rocketteam)
#   RESOURCE_GROUP        — Azure Resource Group name (e.g. rg-rocketteam)
#   ADO_ORGANIZATION      — Azure DevOps organization (e.g. Zenardi)
#   ADO_ORG_AGENT_POOL    — Org-scoped agent pool name (e.g. kind-backstage)
#   ADO_PAT               — ADO Personal Access Token for agent registration
#   ADO_AGENTS_COUNT      — Number of agent pods to deploy (default: 2)
#   CROSSPLANE_SP_CLIENT_ID     — Crossplane SP App ID
#   CROSSPLANE_SP_CLIENT_SECRET — Crossplane SP Secret
#   CROSSPLANE_SP_TENANT_ID     — Azure Tenant ID
#   CROSSPLANE_SUBSCRIPTION_ID  — Azure Subscription ID
#
# Output (written to /tmp/platform-outputs.env):
#   ARGOCD_PASSWORD       — ArgoCD initial admin password

set -euo pipefail

: "${AKS_NAME:?AKS_NAME required}"
: "${RESOURCE_GROUP:?RESOURCE_GROUP required}"
: "${ADO_ORGANIZATION:?ADO_ORGANIZATION required}"
: "${ADO_ORG_AGENT_POOL:?ADO_ORG_AGENT_POOL required}"
: "${ADO_PAT:?ADO_PAT required}"
: "${CROSSPLANE_SP_CLIENT_ID:?CROSSPLANE_SP_CLIENT_ID required}"
: "${CROSSPLANE_SP_CLIENT_SECRET:?CROSSPLANE_SP_CLIENT_SECRET required}"
: "${CROSSPLANE_SP_TENANT_ID:?CROSSPLANE_SP_TENANT_ID required}"
: "${CROSSPLANE_SUBSCRIPTION_ID:?CROSSPLANE_SUBSCRIPTION_ID required}"

ADO_AGENTS_COUNT="${ADO_AGENTS_COUNT:-2}"

echo "🔗 Getting AKS credentials for $AKS_NAME..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --overwrite-existing

echo "✅ Connected to AKS cluster"
kubectl cluster-info

# ─── Add Helm repos ─────────────────────────────────────────────────────────
echo "📦 Adding Helm repositories..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
helm repo add cert-manager https://charts.jetstack.io --force-update
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo add crossplane-stable https://charts.crossplane.io/stable --force-update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo add azure-devops-agent https://joaocc.github.io/helm-azure-devops-agent --force-update 2>/dev/null || \
  helm repo add azure-devops-agent https://charts.devops-agents.io --force-update 2>/dev/null || \
  echo "⚠️  Azure DevOps Agent helm repo not added — will use manifest-based deployment"
helm repo update

# ─── 1. Metrics Server ──────────────────────────────────────────────────────
echo ""
echo "📊 [1/7] Installing Metrics Server..."
helm upgrade metrics-server metrics-server/metrics-server \
  --install --create-namespace -n kube-system \
  --set args[0]="--kubelet-insecure-tls" \
  --wait --timeout 5m
echo "✅ Metrics Server installed"

# ─── 2. Cert Manager ────────────────────────────────────────────────────────
echo ""
echo "🔒 [2/7] Installing Cert Manager..."
helm upgrade cert-manager cert-manager/cert-manager \
  --install --create-namespace -n cert-manager \
  --set installCRDs=true \
  --wait --timeout 5m
echo "✅ Cert Manager installed"

# ─── 3. Traefik ─────────────────────────────────────────────────────────────
echo ""
echo "🌐 [3/7] Installing Traefik..."
helm upgrade traefik traefik/traefik \
  --install --create-namespace -n traefik \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true \
  --set service.type=LoadBalancer \
  --wait --timeout 5m
echo "✅ Traefik installed"

# ─── 4. Crossplane ──────────────────────────────────────────────────────────
echo ""
echo "⚙️  [4/7] Installing Crossplane..."
helm upgrade crossplane crossplane-stable/crossplane \
  --install --create-namespace -n crossplane-system \
  --wait --timeout 10m
echo "✅ Crossplane installed"

# Install Azure Provider Family
echo "  Installing Azure Provider Family..."
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: upbound-provider-family-azure
spec:
  package: xpkg.upbound.io/upbound/provider-family-azure:v2.5.2
  packagePullPolicy: IfNotPresent
EOF

# Wait for provider to install (up to 5 min)
echo "  Waiting for Azure provider to be healthy..."
for i in $(seq 1 30); do
  HEALTHY=$(kubectl get provider upbound-provider-family-azure \
    -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null || echo "")
  if [[ "$HEALTHY" == "True" ]]; then
    echo "  ✅ Azure provider is healthy"
    break
  fi
  echo "  [$i/30] Provider not yet healthy, waiting 10s..."
  sleep 10
done

# Create Azure credentials secret for Crossplane on AKS
echo "  Creating Azure credentials secret on AKS..."
kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-literal=credentials="{\"clientId\":\"$CROSSPLANE_SP_CLIENT_ID\",\"clientSecret\":\"$CROSSPLANE_SP_CLIENT_SECRET\",\"tenantId\":\"$CROSSPLANE_SP_TENANT_ID\",\"subscriptionId\":\"$CROSSPLANE_SUBSCRIPTION_ID\",\"activeDirectoryEndpointUrl\":\"https://login.microsoftonline.com\",\"resourceManagerEndpointUrl\":\"https://management.azure.com/\",\"activeDirectoryGraphResourceId\":\"https://graph.windows.net/\",\"sqlManagementEndpointUrl\":\"https://management.core.windows.net:8443/\",\"galleryEndpointUrl\":\"https://gallery.azure.com/\",\"managementEndpointUrl\":\"https://management.core.windows.net/\"}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply ProviderConfig
cat <<EOF | kubectl apply -f -
apiVersion: azure.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: azure-default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials
      key: credentials
EOF

echo "✅ Crossplane with Azure ProviderConfig configured"

# ─── 5. Prometheus + Grafana ────────────────────────────────────────────────
echo ""
echo "📈 [5/7] Installing Prometheus + Grafana (kube-prometheus-stack)..."
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --install --create-namespace -n monitoring \
  --set grafana.enabled=true \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=7d \
  --set alertmanager.enabled=true \
  --wait --timeout 10m
echo "✅ Prometheus + Grafana installed"

# ─── 6. ArgoCD ──────────────────────────────────────────────────────────────
echo ""
echo "🔁 [6/7] Installing ArgoCD..."
helm upgrade argocd argo/argo-cd \
  --install --create-namespace -n argocd \
  --set configs.params."server\.insecure"=true \
  --set server.service.type=LoadBalancer \
  --wait --timeout 10m

echo "  Retrieving ArgoCD initial admin password..."
ARGOCD_PASSWORD=$(kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode)

echo "  ArgoCD initial password retrieved ✅"
echo "ARGOCD_PASSWORD=$ARGOCD_PASSWORD" >> /tmp/platform-outputs.env
echo "✅ ArgoCD installed"

# ─── 7. Azure DevOps Agents ─────────────────────────────────────────────────
echo ""
echo "🤖 [7/7] Installing Azure DevOps Agents..."

# Create ADO agent namespace and secret
kubectl create namespace azuredevops-agents --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic azdevops-agent-secret \
  -n azuredevops-agents \
  --from-literal=AZP_TOKEN="$ADO_PAT" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy ADO agents using a Deployment manifest
ADO_ORG_URL="https://dev.azure.com/$ADO_ORGANIZATION"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azdevops-agent
  namespace: azuredevops-agents
  labels:
    app: azdevops-agent
spec:
  replicas: $ADO_AGENTS_COUNT
  selector:
    matchLabels:
      app: azdevops-agent
  template:
    metadata:
      labels:
        app: azdevops-agent
    spec:
      containers:
        - name: agent
          image: mcr.microsoft.com/azure-pipelines/vsts-agent:ubuntu-20.04
          env:
            - name: AZP_URL
              value: "$ADO_ORG_URL"
            - name: AZP_POOL
              value: "$ADO_ORG_AGENT_POOL"
            - name: AZP_TOKEN
              valueFrom:
                secretKeyRef:
                  name: azdevops-agent-secret
                  key: AZP_TOKEN
            - name: AZP_AGENT_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 2
              memory: 4Gi
          volumeMounts:
            - mountPath: /var/run/docker.sock
              name: docker-sock
      volumes:
        - name: docker-sock
          hostPath:
            path: /var/run/docker.sock
EOF

kubectl rollout status deployment/azdevops-agent -n azuredevops-agents --timeout=5m
echo "✅ Azure DevOps Agents deployed ($ADO_AGENTS_COUNT replicas)"

echo ""
echo "🎉 AKS Platform installation complete!"
echo "   Installed: Metrics Server, Cert Manager, Traefik, Crossplane, Prometheus+Grafana, ArgoCD, ADO Agents"
