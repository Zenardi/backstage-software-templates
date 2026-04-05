#!/usr/bin/env bash
# test-azure-auth.sh — Validate Azure credentials from azure-creds.json
# Tests authentication and checks permissions needed for the platform.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDS_FILE="$(dirname "$SCRIPT_DIR")/clusterproviderconfig/azure-creds.json"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  AKS GitOps Platform — Azure Auth Test"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─── Read credentials ────────────────────────────────────────────────────────
if [[ ! -f "$CREDS_FILE" ]]; then
  echo "❌ Credentials file not found: $CREDS_FILE"
  exit 1
fi

CLIENT_ID=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['clientId'])")
CLIENT_SECRET=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['clientSecret'])")
TENANT_ID=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['tenantId'])")
SUBSCRIPTION_ID=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['subscriptionId'])")

echo "Using credentials:"
echo "  Client ID:       ${CLIENT_ID:0:8}...${CLIENT_ID: -4}"
echo "  Tenant ID:       $TENANT_ID"
echo "  Subscription ID: $SUBSCRIPTION_ID"
echo ""

# ─── 1. Azure login ──────────────────────────────────────────────────────────
echo "▶ Step 1: Azure login..."
az login \
  --service-principal \
  --username "$CLIENT_ID" \
  --password "$CLIENT_SECRET" \
  --tenant "$TENANT_ID" \
  --output none
az account set --subscription "$SUBSCRIPTION_ID"
echo "  ✅ Azure login successful"

# ─── 2. Validate subscription access ─────────────────────────────────────────
echo ""
echo "▶ Step 2: Validating subscription access..."
SUB_NAME=$(az account show --query name -o tsv)
echo "  ✅ Subscription: $SUB_NAME"

# ─── 3. Check SP object ID ────────────────────────────────────────────────────
echo ""
echo "▶ Step 3: Retrieving Service Principal Object ID..."
SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv 2>/dev/null || echo "")
if [[ -n "$SP_OBJECT_ID" ]]; then
  echo "  ✅ SP Object ID: $SP_OBJECT_ID"
  echo ""
  echo "  📋 Use this as 'Crossplane Service Principal Object ID' in the Backstage template:"
  echo "     $SP_OBJECT_ID"
else
  echo "  ⚠️  Could not retrieve SP Object ID (may require Graph permissions)"
fi

# ─── 4. Check Contributor role ───────────────────────────────────────────────
echo ""
echo "▶ Step 4: Checking Contributor role..."
HAS_CONTRIBUTOR=$(az role assignment list \
  --assignee "$CLIENT_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --query "[0].roleDefinitionName" -o tsv 2>/dev/null || echo "")
if [[ "$HAS_CONTRIBUTOR" == "Contributor" ]]; then
  echo "  ✅ Contributor role confirmed on subscription"
else
  echo "  ⚠️  Contributor role not found. The SP may still work with limited permissions."
fi

# ─── 5. Quick resource group test (dry run) ───────────────────────────────────
echo ""
echo "▶ Step 5: Testing resource group operations..."
TEST_RG="rg-backstage-test-auth-$RANDOM"
az group create --name "$TEST_RG" --location westeurope --output none
echo "  ✅ Resource Group creation works: $TEST_RG"
az group delete --name "$TEST_RG" --yes --no-wait --output none
echo "  ✅ Resource Group deletion initiated"

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Azure auth test passed!"
echo ""
echo "  Copy these values to the Backstage template form:"
echo "    Subscription ID:  $SUBSCRIPTION_ID"
echo "    Tenant ID:        $TENANT_ID"
echo "    SP Client ID:     $CLIENT_ID"
if [[ -n "${SP_OBJECT_ID:-}" ]]; then
echo "    SP Object ID:     $SP_OBJECT_ID"
fi
echo "═══════════════════════════════════════════════════════════"
echo ""
