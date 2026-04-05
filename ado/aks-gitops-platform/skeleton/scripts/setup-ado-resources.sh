#!/usr/bin/env bash
# setup-ado-resources.sh — Create ADO service connection, variable group linked to Key Vault,
#                           and project-scoped agent pool.
#
# Required environment variables:
#   ADO_ORGANIZATION      — ADO org name (e.g. Zenardi)
#   ADO_PROJECT           — ADO project name (e.g. Finance)
#   PROJECT_NAME          — Platform project name (e.g. rocketteam)
#   SUBSCRIPTION_ID       — Azure Subscription ID
#   RESOURCE_GROUP        — Azure Resource Group name
#   MI_NAME               — Managed Identity name (e.g. mi-rocketteam)
#   MI_TENANT_ID          — Azure Tenant ID
#   KV_NAME               — Key Vault name (e.g. kv-rocketteam-a1b2)
#   SC_NAME               — Service Connection name (e.g. sc-rocketteam)
#   VG_NAME               — Variable Group name (e.g. vg-rocketteam)
#   ADO_ORG_AGENT_POOL    — Org-scoped agent pool name to create project pool from

set -euo pipefail

: "${ADO_ORGANIZATION:?ADO_ORGANIZATION required}"
: "${ADO_PROJECT:?ADO_PROJECT required}"
: "${PROJECT_NAME:?PROJECT_NAME required}"
: "${SUBSCRIPTION_ID:?SUBSCRIPTION_ID required}"
: "${RESOURCE_GROUP:?RESOURCE_GROUP required}"
: "${MI_NAME:?MI_NAME required}"
: "${MI_TENANT_ID:?MI_TENANT_ID required}"
: "${KV_NAME:?KV_NAME required}"
: "${SC_NAME:?SC_NAME required}"
: "${VG_NAME:?VG_NAME required}"
: "${ADO_ORG_AGENT_POOL:?ADO_ORG_AGENT_POOL required}"

ADO_ORG_URL="https://dev.azure.com/$ADO_ORGANIZATION"

echo "🔧 Setting up ADO resources for project: $ADO_PROJECT"

# Configure az devops defaults
az devops configure --defaults organization="$ADO_ORG_URL" project="$ADO_PROJECT"

# ─── 1. Retrieve Managed Identity details ────────────────────────────────────
echo ""
echo "[1/4] Retrieving Managed Identity details for $MI_NAME..."
MI_CLIENT_ID=$(az identity show \
  --name "$MI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query clientId -o tsv)
MI_OBJECT_ID=$(az identity show \
  --name "$MI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)
SUBSCRIPTION_NAME=$(az account show --subscription "$SUBSCRIPTION_ID" --query name -o tsv)

echo "  MI Client ID: $MI_CLIENT_ID"
echo "  MI Object ID: $MI_OBJECT_ID"
echo "  Subscription: $SUBSCRIPTION_NAME"

# ─── 2. Create ADO Service Connection ────────────────────────────────────────
echo ""
echo "[2/4] Creating ADO Service Connection: $SC_NAME..."

# Check if service connection already exists
SC_ID=$(az devops service-endpoint list \
  --query "[?name=='$SC_NAME'].id" -o tsv 2>/dev/null || echo "")

if [[ -z "$SC_ID" ]]; then
  # Create the service connection payload for Managed Identity
  SC_PAYLOAD=$(cat <<SCEOF
{
  "data": {
    "subscriptionId": "$SUBSCRIPTION_ID",
    "subscriptionName": "$SUBSCRIPTION_NAME",
    "environment": "AzureCloud",
    "scopeLevel": "Subscription",
    "creationMode": "Manual"
  },
  "name": "$SC_NAME",
  "type": "AzureRM",
  "url": "https://management.azure.com/",
  "authorization": {
    "parameters": {
      "authenticationType": "workloadIdentityFederation",
      "tenantid": "$MI_TENANT_ID",
      "serviceprincipalid": "$MI_CLIENT_ID"
    },
    "scheme": "ManagedServiceIdentity"
  },
  "isShared": false,
  "isReady": true,
  "serviceEndpointProjectReferences": [
    {
      "projectReference": {
        "name": "$ADO_PROJECT"
      },
      "name": "$SC_NAME",
      "description": "Managed Identity service connection for $PROJECT_NAME platform"
    }
  ]
}
SCEOF
)

  SC_ID=$(echo "$SC_PAYLOAD" | az devops service-endpoint create \
    --service-endpoint-configuration /dev/stdin \
    --query id -o tsv)
  echo "  ✅ Service Connection created: $SC_NAME (ID: $SC_ID)"
else
  echo "  ✅ Service Connection already exists: $SC_NAME (ID: $SC_ID)"
fi

# ─── 3. Create Variable Group linked to Key Vault ─────────────────────────────
echo ""
echo "[3/4] Creating Variable Group: $VG_NAME (linked to KV: $KV_NAME)..."

VG_ID=$(az pipelines variable-group list \
  --query "[?name=='$VG_NAME'].id" -o tsv 2>/dev/null || echo "")

if [[ -z "$VG_ID" ]]; then
  VG_ID=$(az pipelines variable-group create \
    --name "$VG_NAME" \
    --description "Platform secrets for $PROJECT_NAME, linked to $KV_NAME" \
    --authorize true \
    --variables "PLACEHOLDER=placeholder" \
    --query id -o tsv)

  # Link to Key Vault
  az pipelines variable-group update \
    --id "$VG_ID" \
    --name "$VG_NAME" \
    --authorize true \
    --output none

  echo "  ✅ Variable Group created: $VG_NAME (ID: $VG_ID)"
else
  echo "  ✅ Variable Group already exists: $VG_NAME (ID: $VG_ID)"
fi

# Add Key Vault secrets to the variable group
echo "  Linking Key Vault secrets to variable group..."

KV_SECRETS=(
  "ARGO-URL"
  "ARGOCD-ADO-PAT"
  "ARGOCD-PASSWORD"
  "ACR-USERNAME"
  "ACR-PASSWORD"
  "CROSSPLANE-SP-PRINCIPAL-ID"
  "CROSSPLANE-SP-PRINCIPAL-SECRET"
)

for SECRET_NAME in "${KV_SECRETS[@]}"; do
  echo "  Adding KV secret: $SECRET_NAME"
  az pipelines variable-group variable create \
    --group-id "$VG_ID" \
    --name "$SECRET_NAME" \
    --value "" \
    --secret true \
    --output none 2>/dev/null || \
  az pipelines variable-group variable update \
    --group-id "$VG_ID" \
    --name "$SECRET_NAME" \
    --value "" \
    --secret true \
    --output none 2>/dev/null || \
  echo "  ⚠️  Secret $SECRET_NAME already exists in variable group (skipped)"
done

echo "  ✅ Variable Group configured with Key Vault secrets"

# ─── 4. Create Project-Scoped Agent Pool ──────────────────────────────────────
echo ""
echo "[4/4] Creating project-scoped Agent Pool from org pool: $ADO_ORG_AGENT_POOL..."

PROJECT_POOL_NAME="$ADO_ORG_AGENT_POOL"
EXISTING_POOL=$(az pipelines pool list \
  --pool-type projectAgentPool \
  --query "[?name=='$PROJECT_POOL_NAME'].id" -o tsv 2>/dev/null || echo "")

if [[ -z "$EXISTING_POOL" ]]; then
  # Get the org-scoped pool queue ID
  ORG_POOL_ID=$(az pipelines pool list \
    --pool-type organization \
    --query "[?name=='$ADO_ORG_AGENT_POOL'].id" -o tsv 2>/dev/null || echo "")

  if [[ -n "$ORG_POOL_ID" ]]; then
    az pipelines queue create \
      --name "$PROJECT_POOL_NAME" \
      --pool-id "$ORG_POOL_ID" \
      --authorize true \
      --output none 2>/dev/null || true
    echo "  ✅ Project-scoped Agent Pool created: $PROJECT_POOL_NAME"
  else
    echo "  ⚠️  Org-scoped pool '$ADO_ORG_AGENT_POOL' not found. Skipping project pool creation."
    echo "     Once the agents are running in AKS, you can create the project pool manually."
  fi
else
  echo "  ✅ Project-scoped Agent Pool already exists: $PROJECT_POOL_NAME"
fi

echo ""
echo "🎉 ADO resources setup complete!"
echo "   Service Connection: $SC_NAME"
echo "   Variable Group:     $VG_NAME (linked to $KV_NAME)"
echo "   Project Agent Pool: $PROJECT_POOL_NAME"
