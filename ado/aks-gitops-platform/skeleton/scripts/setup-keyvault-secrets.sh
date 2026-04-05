#!/usr/bin/env bash
# setup-keyvault-secrets.sh — Store all platform secrets in Azure Key Vault.
#
# Required environment variables:
#   KV_NAME               — Key Vault name (e.g. kv-rocketteam-a1b2)
#   ARGOCD_URL            — ArgoCD server URL
#   ARGOCD_ADO_PAT        — ADO PAT for ArgoCD git sync
#   ARGOCD_PASSWORD       — ArgoCD initial admin password (from install step)
#   ACR_NAME              — Azure Container Registry name
#   RESOURCE_GROUP        — Resource Group containing the ACR
#   CROSSPLANE_SP_CLIENT_ID     — Crossplane SP App ID
#   CROSSPLANE_SP_CLIENT_SECRET — Crossplane SP Secret

set -euo pipefail

: "${KV_NAME:?KV_NAME required}"
: "${ARGOCD_URL:?ARGOCD_URL required}"
: "${ARGOCD_ADO_PAT:?ARGOCD_ADO_PAT required}"
: "${ARGOCD_PASSWORD:?ARGOCD_PASSWORD required}"
: "${ACR_NAME:?ACR_NAME required}"
: "${RESOURCE_GROUP:?RESOURCE_GROUP required}"
: "${CROSSPLANE_SP_CLIENT_ID:?CROSSPLANE_SP_CLIENT_ID required}"
: "${CROSSPLANE_SP_CLIENT_SECRET:?CROSSPLANE_SP_CLIENT_SECRET required}"

echo "🔑 Storing secrets in Key Vault: $KV_NAME"

# Wait until Key Vault is accessible
echo "  Waiting for Key Vault to be accessible..."
for i in $(seq 1 20); do
  if az keyvault show --name "$KV_NAME" --query id -o tsv &>/dev/null; then
    echo "  ✅ Key Vault accessible"
    break
  fi
  echo "  [$i/20] Waiting 15s..."
  sleep 15
  if [[ "$i" == "20" ]]; then
    echo "  ❌ Key Vault not accessible after 5m. Exiting."
    exit 1
  fi
done

set_secret() {
  local secret_name="$1"
  local secret_value="$2"
  echo "  Setting secret: $secret_name"
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "$secret_name" \
    --value "$secret_value" \
    --output none
}

# ─── ArgoCD secrets ──────────────────────────────────────────────────────────
set_secret "ARGO-URL"       "$ARGOCD_URL"
set_secret "ARGOCD-ADO-PAT" "$ARGOCD_ADO_PAT"
set_secret "ARGOCD-PASSWORD" "$ARGOCD_PASSWORD"

# ─── ACR credentials ─────────────────────────────────────────────────────────
echo "  Retrieving ACR credentials for $ACR_NAME..."
ACR_USERNAME=$(az acr credential show \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query username -o tsv)
ACR_PASSWORD=$(az acr credential show \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "passwords[0].value" -o tsv)

set_secret "ACR-USERNAME" "$ACR_USERNAME"
set_secret "ACR-PASSWORD" "$ACR_PASSWORD"

# ─── Crossplane SP secrets ────────────────────────────────────────────────────
set_secret "CROSSPLANE-SP-PRINCIPAL-ID"     "$CROSSPLANE_SP_CLIENT_ID"
set_secret "CROSSPLANE-SP-PRINCIPAL-SECRET" "$CROSSPLANE_SP_CLIENT_SECRET"

echo ""
echo "✅ All secrets stored in Key Vault $KV_NAME:"
echo "   ARGO-URL, ARGOCD-ADO-PAT, ARGOCD-PASSWORD"
echo "   ACR-USERNAME, ACR-PASSWORD"
echo "   CROSSPLANE-SP-PRINCIPAL-ID, CROSSPLANE-SP-PRINCIPAL-SECRET"
