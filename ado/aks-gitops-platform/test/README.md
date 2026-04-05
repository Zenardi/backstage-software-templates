# AKS GitOps Platform — Test Suite

This folder contains tests to validate the template implementation before using it in Backstage.

## System Requirements for `test-crossplane-apply.sh`

Crossplane v2.x requires `fs.inotify.max_user_instances >= 1280` on the host.
Check your current value:
```bash
cat /proc/sys/fs/inotify/max_user_instances   # must be >= 1280
```

To set it (requires host sudo):
```bash
sudo sysctl -w fs.inotify.max_user_instances=1280
sudo sysctl -w fs.inotify.max_user_watches=655360
# Persist across reboots:
echo "fs.inotify.max_user_instances=1280" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=655360"  | sudo tee -a /etc/sysctl.conf
```

If you cannot raise the limit, `test-crossplane-apply.sh` and `test-claim-apply.sh` will fail
with "too many open files". The rest of the validation (`validate-all.sh`, `test-azure-auth.sh`)
works without this requirement.

| File | Description |
|---|---|
| `test-xrd-composition.sh` | Validates XRD and Composition YAML with `kubectl --dry-run` |
| `test-claim-dry-run.sh` | Validates the claim YAML structure |
| `test-scripts-syntax.sh` | Validates all shell scripts with `bash -n` |
| `test-azure-auth.sh` | Tests Azure authentication with the real credentials |
| `test-crossplane-apply.sh` | Applies providers + XRD + Composition to KIND cluster (requires running cluster) |
| `test-claim-apply.sh` | Applies a test claim to KIND cluster (provisions real Azure resources — COSTS MONEY) |
| `validate-all.sh` | Runs all non-destructive tests |

## Quick Start

```bash
# Run all non-destructive validations (no Azure cost)
cd test/
bash validate-all.sh

# Test Azure authentication
bash test-azure-auth.sh

# Apply providers + XRD + Composition to KIND cluster (no Azure cost)
bash test-crossplane-apply.sh

# Full end-to-end test (provisions real Azure resources — ~$5/hour while running)
bash test-claim-apply.sh
```

## Credentials

The `azure-creds.json` file (in `ado/aks-gitops-platform/clusterproviderconfig/`) contains the
credentials used in tests. These match the Crossplane ProviderConfig already on the KIND cluster.

## Cleanup

After running `test-claim-apply.sh`:
```bash
kubectl delete aksgitotsplatformclaim test-platform
# Wait a few minutes for Crossplane to delete all Azure resources
az group delete --name rg-testplatform --yes --no-wait
```
