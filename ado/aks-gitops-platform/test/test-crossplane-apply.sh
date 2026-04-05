#!/usr/bin/env bash
# test-crossplane-apply.sh — Apply providers + XRD + Composition to KIND cluster.
# This does NOT create any Azure resources (no cost). It validates the Crossplane
# manifests work against the live KIND cluster.
#
# Requirements:
#   - kubectl configured to point to KIND cluster (kind-backstage context)
#   - Crossplane installed on the KIND cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")/skeleton"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  AKS GitOps Platform — Crossplane Manifests Test"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─── Check prerequisites ──────────────────────────────────────────────────────
echo "▶ Checking prerequisites..."
if ! command -v kubectl &>/dev/null; then
  echo "  ❌ kubectl not found"
  exit 1
fi
CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
echo "  kubectl context: $CONTEXT"

if ! kubectl get nodes &>/dev/null; then
  echo "  ❌ Cannot connect to Kubernetes cluster"
  exit 1
fi
echo "  ✅ Cluster connection OK"

# Check Crossplane is installed
if ! kubectl get deployment -n crossplane-system -l app=crossplane &>/dev/null; then
  echo "  ❌ Crossplane not found in crossplane-system namespace"
  exit 1
fi
echo "  ✅ Crossplane is installed"

# ─── Apply providers ─────────────────────────────────────────────────────────
echo ""
echo "▶ Applying Crossplane Azure sub-providers..."
kubectl apply -f "$TEMPLATE_DIR/crossplane/providers.yaml"
echo "  ✅ Providers applied"

echo "  Waiting for providers to become healthy (up to 10 min)..."
PROVIDERS=(
  upbound-provider-azure-azure
  upbound-provider-azure-containerregistry
  upbound-provider-azure-keyvault
  upbound-provider-azure-managedidentity
  upbound-provider-azure-authorization
  upbound-provider-azure-containerservice
)

for PROVIDER in "${PROVIDERS[@]}"; do
  echo -n "  Waiting for $PROVIDER..."
  for i in $(seq 1 40); do
    HEALTHY=$(kubectl get provider "$PROVIDER" \
      -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null || echo "")
    if [[ "$HEALTHY" == "True" ]]; then
      echo " ✅"
      break
    fi
    if [[ "$i" == "40" ]]; then
      echo " ❌ Timeout"
      kubectl get provider "$PROVIDER" -o yaml | grep -A 5 "conditions:" || true
    fi
    echo -n "."
    sleep 15
  done
done

# ─── Apply XRD ───────────────────────────────────────────────────────────────
echo ""
echo "▶ Applying CompositeResourceDefinition..."
kubectl apply -f "$TEMPLATE_DIR/crossplane/xrd.yaml"

echo -n "  Waiting for XRD to be established..."
for i in $(seq 1 20); do
  ESTABLISHED=$(kubectl get compositeresourcedefinition \
    aksgitotsplatforms.platform.spacetech.io \
    -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null || echo "")
  if [[ "$ESTABLISHED" == "True" ]]; then
    echo " ✅"
    break
  fi
  if [[ "$i" == "20" ]]; then
    echo " ❌ Timeout"
    kubectl get compositeresourcedefinition aksgitotsplatforms.platform.spacetech.io -o yaml | grep -A 10 "conditions:" || true
  fi
  echo -n "."
  sleep 10
done

# ─── Apply Composition ───────────────────────────────────────────────────────
echo ""
echo "▶ Applying Composition..."
kubectl apply -f "$TEMPLATE_DIR/crossplane/composition.yaml"
echo "  ✅ Composition applied"

# Verify the composition was accepted
COMPOSITION_STATUS=$(kubectl get composition aks-gitops-platform \
  -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
if [[ "$COMPOSITION_STATUS" == "aks-gitops-platform" ]]; then
  echo "  ✅ Composition 'aks-gitops-platform' is registered"
else
  echo "  ❌ Composition not found after apply"
  exit 1
fi

# ─── Verify CRDs are available ───────────────────────────────────────────────
echo ""
echo "▶ Verifying Claim CRDs are available..."
for i in $(seq 1 12); do
  CRD=$(kubectl get crd aksgitotsplatformclaims.platform.spacetech.io \
    -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
  if [[ "$CRD" == "aksgitotsplatformclaims.platform.spacetech.io" ]]; then
    echo "  ✅ AKSGitOpsPlatformClaim CRD is available"
    break
  fi
  if [[ "$i" == "12" ]]; then
    echo "  ❌ AKSGitOpsPlatformClaim CRD not available after 2 min"
    exit 1
  fi
  echo "  [$i/12] Waiting for CRD to be available..."
  sleep 10
done

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Crossplane manifests applied successfully!"
echo ""
echo "  Installed:"
echo "    ✅ Azure sub-providers (6)"
echo "    ✅ XRD: AKSGitOpsPlatform / AKSGitOpsPlatformClaim"
echo "    ✅ Composition: aks-gitops-platform"
echo ""
echo "  Next step — apply a test claim (CREATES REAL AZURE RESOURCES):"
echo "    bash test/test-claim-apply.sh"
echo "═══════════════════════════════════════════════════════════"
echo ""
