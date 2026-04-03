# Copilot Instructions

This repository contains **Backstage software scaffolder templates** for a Platform Engineering self-service portal. Templates provision applications and infrastructure with integrated CI/CD, Kubernetes deployment via ArgoCD, and monitoring via Grafana/Prometheus.

## Repository Structure

Each top-level directory is a self-contained Backstage template:

| Directory | Type | Stack |
|---|---|---|
| `python-app/` | Service | Python 3.10 / Flask |
| `react-ts-app/` | Website | TypeScript / React 19 / Vite / Nginx |
| `springboot-api/` | API | Java 25 / Spring Boot 4.0 / Maven |
| `springboot-grpc-template/` | Service | Java 25 / Spring Boot 4.0 / gRPC + REST / Maven |
| `crossplane/` | Infrastructure | Crossplane XRs for AWS (EKS, S3, ECR) and Azure (AKS) |
| `ado/react-ts-app/` | Website | TypeScript / React 19 / Vite / Nginx — publishes to Azure DevOps |

## Template Anatomy

Every template contains a root `template.yaml` (Backstage scaffolder spec) and either a `template/` or `skeleton/` directory with the generated project files.

> `springboot-grpc-template` uses `skeleton/` — all others use `template/`.

### `template.yaml` structure

```
spec.parameters   → Backstage UI form fields
spec.steps[0]     → fetch:template (maps parameters → values → files)
spec.steps[1]     → publish:github
spec.steps[2]     → catalog:register
```

### Standard generated file layout

```
.github/workflows/    CI/CD GitHub Actions pipeline
argocd/               ArgoCD Application + AppProject resources
k8s/                  Kubernetes manifests (Deployment, Service, HPA, Ingress)
docs/                 MkDocs documentation
src/                  Application source code
catalog-info.yaml     Backstage component registration
mkdocs.yaml           Docs config
Dockerfile            Multi-stage build
```

## Key Conventions

### Parameter naming (template.yaml)
- `component_id` — kebab-case app name, regex `^([a-zA-Z][a-zA-Z0-9]*)(-[a-zA-Z0-9]+)*$`
- `environment` — enum: `poc | dev | staging | prod`
- `team` — EntityPicker filtering `Group` with `spec.type=team`
- `system` — OwnerPicker filtering `System` with `spec.domain=spacetech`
- `image_registry` — defaults to `docker.io/zenardi`
- `targetCluster` — EntityPicker for Kubernetes cluster resource

### Value mappings (fetch:template step)
Template files use `${{values.*}}` syntax. Common mappings:
```yaml
app_name:       ${{parameters.component_id}}
app_env:        ${{parameters.environment}}
deploy_replicas: ${{parameters.deploy_replicas}}
destination:    ${{ parameters.repoUrl | parseRepoUrl }}
```

### Kubernetes labels (all manifests)
```yaml
labels:
  app: ${{values.app_name}}
  environment: ${{values.app_env}}
  backstage.io/kubernetes-id: ${{values.app_name}}
  backstage.io/kubernetes-cluster: ${{values.targetCluster.split('/')[1]}}
  backstage.io/kubernetes-namespace: ${{values.system.split('/')[1]}}
```

The namespace is always derived from the system entity: `system.split('/')[1]`.

### Ingress
- Class: `traefik`
- Default domain suffix: `local.com`
- All services exposed on port `8080` at the ingress level regardless of container port.

### Ports by template
- Python Flask: `5000`
- React: `80` (Nginx) + `3000` (Prometheus metrics sidecar)
- Spring Boot REST: `8080`
- Spring Boot gRPC: `8080` (REST) + `9090` (gRPC)

### CI/CD pipeline pattern (GitHub Actions)
Two jobs in every template:
1. **CI** — Docker build & push to DockerHub (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` secrets)
2. **CD** — runs on `self-hosted` runner; installs kubectl + argocd CLI, applies ArgoCD project/app, creates namespace (with retry), applies k8s manifests, waits for rollout (90s timeout). Requires `ARGOCD_PASSWORD` secret.

### ArgoCD
- Sync policy: automated with `prune: true` and `selfHeal: true`
- Source path: `k8s/`
- `ClusterResourceWhitelist` includes Crossplane resource types and `Namespace`

### Monitoring
Every `catalog-info.yaml` includes:
```yaml
grafana/dashboard-selector: "title == '${{values.app_name}}'"
grafana/alert-label-selector: "app=${{values.app_name}}"
```
Java templates expose metrics via Micrometer + Prometheus. React exposes metrics via a Node.js Express sidecar (`prom-client`).

### catalog-info.yaml component types
- Python/gRPC → `type: service`
- React → `type: website`
- Spring Boot REST → `kind: API` with inline OpenAPI 3.0 definition

### Crossplane templates
- Spec type: `crossplane-xr`
- Reference `system.split('/')[1]` for namespace
- Include a prerequisite confirmation parameter before provisioning (e.g., "Have you installed the ClusterProviderConfig?")
- Provider versions pinned in `provider.yaml`

## Azure DevOps Templates (`ado/`)

Templates under `ado/` mirror their counterparts but publish to Azure DevOps and use Azure Pipelines instead of GitHub Actions.

Key differences from GitHub-based templates:

| Concern | GitHub template | ADO template |
|---|---|---|
| Scaffolder publish action | `publish:github` | `publish:azure` |
| `repoUrl` allowed host | `github.com` | `dev.azure.com` |
| CI/CD file | `.github/workflows/${{values.app_name}}-cicd.yaml` | `azure-pipelines.yml` |
| catalog annotation | `github.com/project-slug` | `dev.azure.com/project-repo` |

ADO templates require an extra `ado_project` parameter (Azure DevOps project name) because the git URL format is `https://dev.azure.com/{org}/{project}/_git/{repo}` and the project is not captured by `RepoUrlPicker`.

**`catalog-info.yaml` ADO annotation:**
```yaml
dev.azure.com/project-repo: ${{values.destination.owner + "/" + values.ado_project + "/" + values.destination.repo}}
```

**ArgoCD `application.yaml` ADO repoURL:**
```yaml
repoURL: https://dev.azure.com/${{values.destination.owner}}/${{values.ado_project}}/_git/${{values.destination.repo}}
```

**Azure Pipelines structure** (`azure-pipelines.yml`):
- Stage `CI`: runs on `ubuntu-latest`, uses `Docker@2` task with a `dockerhub` service connection
- Stage `CD`: runs on `pool: name: Default` (self-hosted, must have access to local KIND cluster), uses the same kubectl + argocd login + deploy pattern as GitHub CD jobs
- Pipeline variables: `$(DOCKERHUB_USERNAME)`, `$(DOCKERHUB_TOKEN)`, `$(ARGOCD_PASSWORD)` — set these in ADO pipeline settings or a Variable Group

## Build Commands (within generated projects)

**React (`react-ts-app/template/`)**
```bash
npm run dev        # dev server
npm run build      # tsc + vite build
npm run lint       # eslint
npm run preview    # preview build
```

**Spring Boot (`springboot-api/template/` or `springboot-grpc-template/skeleton/`)**
```bash
./mvnw spring-boot:run          # run locally
./mvnw test                     # full test suite
./mvnw test -Dtest=MyTest       # single test class
./mvnw package -DskipTests      # build JAR
```

**Python (`python-app/template/`)**
```bash
pip install -r requirements.txt
python app.py
```
