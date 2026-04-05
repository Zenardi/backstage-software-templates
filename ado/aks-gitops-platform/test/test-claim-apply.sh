#!/usr/bin/env bash
# test-claim-apply.sh — Apply a test AKSGitOpsPlatformClaim to KIND cluster.
#
# ⚠️  WARNING: This provisions REAL Azure resources and will incur costs (~$5-10/hour).
#             Always run cleanup when done.
#
# Requirements:
#   - test-crossplane-apply.sh completed successfully
#   - azure-creds.json present in clusterproviderconfig/
#   - kubectl pointing to KIND cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDS_FILE="$(dirname "$SCRIPT_DIR")/clusterproviderconfig/azure-creds.json"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  AKS GitOps Platform — Live Claim Test"
echo "  ⚠️  This creates REAL Azure resources (has cost)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─── Read credentials ────────────────────────────────────────────────────────
CLIENT_ID=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['clientId'])")
CLIENT_SECRET=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['clientSecret'])")
TENANT_ID=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['tenantId'])")
SUBSCRIPTION_ID=$(python3 -c "import json; print(json.load(open('$CREDS_FILE'))['subscriptionId'])")

# Get SP Object ID
az login --service-principal \
  --username "$CLIENT_ID" \
  --password "$CLIENT_SECRET" \
  --tenant "$TENANT_ID" \
  --output none
SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)

echo "Credentials loaded:"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  SP Object ID: $SP_OBJECT_ID"
echo ""
echo "  Press Ctrl+C to cancel, or wait 10 seconds to continue..."
sleep 10

# ─── Apply test claim ─────────────────────────────────────────────────────────
echo ""
echo "▶ Applying test AKSGitOpsPlatformClaim..."
cat <<EOF | kubectl apply -f -
apiVersion: platform.spacetech.io/v1alpha1
kind: AKSGitOpsPlatformClaim
metadata:
  name: test-platform
  namespace: default
spec:
  compositionSelector:
    matchLabels:
      provider: azure
      platform: aks-gitops
  parameters:
    projectName: testplatform
    subscriptionId: "$SUBSCRIPTION_ID"
    tenantId: "$TENANT_ID"
    location: westeurope
    acrName: "acrtestplatform"
    kvSuffix: "ts01"
    crossplaneSpObjectId: "$SP_OBJECT_ID"
EOF

echo "  ✅ Test claim applied: test-platform"

# ─── Wait and watch ───────────────────────────────────────────────────────────
echo ""
echo "▶ Monitoring provisioning (watching every 30s, Ctrl+C to stop watching)..."
echo "  Resources being created: rg-testplatform, acrtestplatform, kv-testplatform-ts01,"
echo "  mi-testplatform, role assignments, aks-testplatform"
echo ""

for i in $(seq 1 60); do
  echo "--- [$i/60] $(date '+%H:%M:%S') ---"
  kubectl get aksgitotsplatformclaim test-platform \
    -o custom-columns="NAME:.metadata.name,READY:.status.conditions[0].status,SYNCED:.status.conditions[1].status,MESSAGE:.status.conditions[0].message" \
    2>/dev/null | head -3 || true
  echo ""
  
  READY=$(kubectl get aksgitotsplatformclaim test-platform \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$READY" == "True" ]]; then
    echo "🎉 Claim is Ready! All Azure resources provisioned."
    break
  fi
  
  if [[ "$i" == "60" ]]; then
    echo "⏰ Reached watch limit. Claim may still be provisioning (AKS can take 15-20 min)."
    echo "   Check status with: kubectl get aksgitotsplatformclaim test-platform"
  fi
  sleep 30
done

# ─── Show individual resource status ─────────────────────────────────────────
echo ""
echo "▶ Individual resource status:"
kubectl get resourcegroup,registry,vault,userassignedidentity,kubernetescluster \
  -l crossplane.io/composite 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  CLEANUP when done:"
echo "  kubectl delete aksgitotsplatformclaim test-platform"
echo "  # Then wait for Crossplane to delete all resources,"
echo "  # or forcefully: az group delete --name rg-testplatform --yes"
echo "═══════════════════════════════════════════════════════════"
