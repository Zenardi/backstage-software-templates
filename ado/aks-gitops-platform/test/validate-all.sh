#!/usr/bin/env bash
# validate-all.sh — Run all non-destructive tests for the AKS GitOps Platform template.
# No Azure costs are incurred by this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")"
PASS=0
FAIL=0

run_test() {
  local name="$1"
  local cmd="$2"
  printf "  %-55s" "$name..."
  if eval "$cmd" &>/dev/null; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL"
    eval "$cmd" 2>&1 | head -5 | sed 's/^/     /'
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  AKS GitOps Platform — Template Validation"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─── 1. Check required files exist ──────────────────────────────────────────
echo "▶ Checking required files..."
REQUIRED_FILES=(
  "template.yaml"
  "skeleton/catalog-info.yaml"
  "skeleton/azure-pipelines.yml"
  "skeleton/crossplane/providers.yaml"
  "skeleton/crossplane/xrd.yaml"
  "skeleton/crossplane/composition.yaml"
  "skeleton/crossplane/claim.yaml"
  "skeleton/scripts/wait-crossplane.sh"
  "skeleton/scripts/install-aks-platform.sh"
  "skeleton/scripts/setup-keyvault-secrets.sh"
  "skeleton/scripts/setup-ado-resources.sh"
)
for f in "${REQUIRED_FILES[@]}"; do
  run_test "File exists: $f" "test -f '$TEMPLATE_DIR/$f'"
done

# ─── 2. Validate YAML syntax ─────────────────────────────────────────────────
echo ""
echo "▶ Validating YAML syntax..."
if command -v python3 &>/dev/null; then
  run_test "template.yaml is valid YAML" \
    "python3 -c \"import yaml; list(yaml.safe_load_all(open('$TEMPLATE_DIR/template.yaml')))\""
  run_test "xrd.yaml is valid YAML" \
    "python3 -c \"import yaml; list(yaml.safe_load_all(open('$TEMPLATE_DIR/skeleton/crossplane/xrd.yaml')))\""
  run_test "composition.yaml is valid YAML" \
    "python3 -c \"import yaml; list(yaml.safe_load_all(open('$TEMPLATE_DIR/skeleton/crossplane/composition.yaml')))\""
  run_test "claim.yaml is valid YAML" \
    "python3 -c \"import yaml; list(yaml.safe_load_all(open('$TEMPLATE_DIR/skeleton/crossplane/claim.yaml')))\""
  run_test "providers.yaml is valid YAML" \
    "python3 -c \"import yaml; list(yaml.safe_load_all(open('$TEMPLATE_DIR/skeleton/crossplane/providers.yaml')))\""
  run_test "catalog-info.yaml is valid YAML" \
    "python3 -c \"import yaml; list(yaml.safe_load_all(open('$TEMPLATE_DIR/skeleton/catalog-info.yaml')))\""
  run_test "azure-pipelines.yml is valid YAML" \
    "python3 -c \"import yaml; list(yaml.safe_load_all(open('$TEMPLATE_DIR/skeleton/azure-pipelines.yml')))\""
else
  echo "  ⚠️  python3 not available, skipping YAML validation"
fi

# ─── 3. Validate shell script syntax ─────────────────────────────────────────
echo ""
echo "▶ Validating shell script syntax..."
for script in wait-crossplane install-aks-platform setup-keyvault-secrets setup-ado-resources; do
  run_test "bash -n scripts/$script.sh" \
    "bash -n '$TEMPLATE_DIR/skeleton/scripts/$script.sh'"
done

# ─── 4. Validate template.yaml structure ─────────────────────────────────────
echo ""
echo "▶ Validating template.yaml structure..."
if command -v python3 &>/dev/null; then
  run_test "template.yaml has apiVersion" \
    "python3 -c \"import yaml; t=yaml.safe_load(open('$TEMPLATE_DIR/template.yaml')); assert t['apiVersion'] == 'scaffolder.backstage.io/v1beta3'\""
  run_test "template.yaml has spec.parameters" \
    "python3 -c \"import yaml; t=yaml.safe_load(open('$TEMPLATE_DIR/template.yaml')); assert len(t['spec']['parameters']) > 0\""
  run_test "template.yaml has spec.steps with fetch:template" \
    "python3 -c \"import yaml; t=yaml.safe_load(open('$TEMPLATE_DIR/template.yaml')); actions=[s['action'] for s in t['spec']['steps']]; assert 'fetch:template' in actions\""
  run_test "template.yaml has spec.steps with publish:azure" \
    "python3 -c \"import yaml; t=yaml.safe_load(open('$TEMPLATE_DIR/template.yaml')); actions=[s['action'] for s in t['spec']['steps']]; assert 'publish:azure' in actions\""
  run_test "template.yaml has spec.steps with catalog:register" \
    "python3 -c \"import yaml; t=yaml.safe_load(open('$TEMPLATE_DIR/template.yaml')); actions=[s['action'] for s in t['spec']['steps']]; assert 'catalog:register' in actions\""
fi

# ─── 5. Validate Crossplane XRD structure ────────────────────────────────────
echo ""
echo "▶ Validating Crossplane XRD structure..."
if command -v python3 &>/dev/null; then
  run_test "XRD kind is CompositeResourceDefinition" \
    "python3 -c \"import yaml; x=yaml.safe_load(open('$TEMPLATE_DIR/skeleton/crossplane/xrd.yaml')); assert x['kind'] == 'CompositeResourceDefinition'\""
  run_test "XRD group is platform.spacetech.io" \
    "python3 -c \"import yaml; x=yaml.safe_load(open('$TEMPLATE_DIR/skeleton/crossplane/xrd.yaml')); assert x['spec']['group'] == 'platform.spacetech.io'\""
  run_test "XRD has claimNames defined" \
    "python3 -c \"import yaml; x=yaml.safe_load(open('$TEMPLATE_DIR/skeleton/crossplane/xrd.yaml')); assert 'claimNames' in x['spec']\""
fi

# ─── 6. Validate Composition structure ───────────────────────────────────────
echo ""
echo "▶ Validating Composition structure..."
if command -v python3 &>/dev/null; then
  run_test "Composition kind is Composition" \
    "python3 -c \"import yaml; c=yaml.safe_load(open('$TEMPLATE_DIR/skeleton/crossplane/composition.yaml')); assert c['kind'] == 'Composition'\""
  run_test "Composition has 7 resources" \
    "python3 -c \"import yaml; c=yaml.safe_load(open('$TEMPLATE_DIR/skeleton/crossplane/composition.yaml')); assert len(c['spec']['resources']) == 7, f'Expected 7, got {len(c[\\\"spec\\\"][\\\"resources\\\"])}'\""
  run_test "Composition references AKSGitOpsPlatform" \
    "python3 -c \"import yaml; c=yaml.safe_load(open('$TEMPLATE_DIR/skeleton/crossplane/composition.yaml')); assert c['spec']['compositeTypeRef']['kind'] == 'AKSGitOpsPlatform'\""
  
  # Check all required resource types
  RESOURCE_TYPES=(
    "ResourceGroup"
    "Registry"
    "Vault"
    "UserAssignedIdentity"
    "RoleAssignment"
    "KubernetesCluster"
  )
  for rt in "${RESOURCE_TYPES[@]}"; do
    run_test "Composition includes $rt" \
      "grep -q 'kind: $rt' '$TEMPLATE_DIR/skeleton/crossplane/composition.yaml'"
  done
fi

# ─── 7. Validate Pipeline structure ──────────────────────────────────────────
echo ""
echo "▶ Validating Azure Pipeline structure..."
run_test "Pipeline has Provision stage" \
  "grep -q 'stage: Provision' '$TEMPLATE_DIR/skeleton/azure-pipelines.yml'"
run_test "Pipeline has ConfigureAKS stage" \
  "grep -q 'stage: ConfigureAKS' '$TEMPLATE_DIR/skeleton/azure-pipelines.yml'"
run_test "Pipeline has ConfigureADO stage" \
  "grep -q 'stage: ConfigureADO' '$TEMPLATE_DIR/skeleton/azure-pipelines.yml'"
run_test "Pipeline uses template variable for agent pool" \
  "grep -q 'ADO_ORG_AGENT_POOL' '$TEMPLATE_DIR/skeleton/azure-pipelines.yml'"

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
if [[ "$FAIL" -eq 0 ]]; then
  echo "  ✅ All $TOTAL tests passed!"
else
  echo "  ❌ $FAIL/$TOTAL tests failed"
  exit 1
fi
echo "═══════════════════════════════════════════════════════════"
echo ""
