#!/usr/bin/env bash
# wait-crossplane.sh — Poll until a Crossplane managed resource is Ready.
#
# Usage:
#   ./wait-crossplane.sh <resource-kind> <resource-name> [timeout-minutes]
#
# Examples:
#   ./wait-crossplane.sh ResourceGroup rg-rocketteam 10
#   ./wait-crossplane.sh KubernetesCluster aks-rocketteam 30
#   ./wait-crossplane.sh AKSGitOpsPlatformClaim rocketteam-platform 35
#
# Exit codes:
#   0 — resource is Ready
#   1 — timeout reached or error

set -euo pipefail

KIND="${1:?Usage: $0 <kind> <name> [timeout-minutes]}"
NAME="${2:?Usage: $0 <kind> <name> [timeout-minutes]}"
TIMEOUT_MIN="${3:-20}"
TIMEOUT_SEC=$(( TIMEOUT_MIN * 60 ))
INTERVAL=15

echo "⏳ Waiting for $KIND/$NAME to be Ready (timeout: ${TIMEOUT_MIN}m)..."

elapsed=0
while true; do
  READY=$(kubectl get "$KIND" "$NAME" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  SYNCED=$(kubectl get "$KIND" "$NAME" \
    -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "")

  if [[ "$READY" == "True" ]]; then
    echo "✅ $KIND/$NAME is Ready (Synced=$SYNCED)"
    exit 0
  fi

  if [[ "$elapsed" -ge "$TIMEOUT_SEC" ]]; then
    echo "❌ Timeout: $KIND/$NAME not Ready after ${TIMEOUT_MIN}m"
    echo "--- Last status ---"
    kubectl get "$KIND" "$NAME" -o yaml 2>/dev/null | grep -A 20 "conditions:" || true
    exit 1
  fi

  # Show current message if available
  MSG=$(kubectl get "$KIND" "$NAME" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || echo "")
  echo "  [$((elapsed/60))m elapsed] Ready=$READY Synced=$SYNCED — ${MSG:0:100}"

  sleep "$INTERVAL"
  elapsed=$(( elapsed + INTERVAL ))
done
