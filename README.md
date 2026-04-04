## Creation Flow - GitOps Platform
### Step 1
Before using backstage, user must create some resources manually to have GitOps Platform, and that is:
- Azure subscription
- Create Azure DevOps Organization
- Create an empty org-scoped Agent Pool on that ADO Org.
- Create PAT: ARGOCD_ADO_PAT so ArgoCD is able to sync with git code

### Step 2
Go to backstage, and fill up the "New Project" template form with:
- ADO Org Name
- Project Name
- Org-scoped Agent Pool Name
- ArgoCD Personal Access Token create on ADO (ARGOCD_ADO_PAT)

This Form will:
1. Create KeyVault with ARGO_URL, ARGOCD_ADO_PAT, ARGOCD_PASSWORD, ACR_USERNAME, ACR_PASSWORD
  - KV Name: kv-bckstg-[project-name]
2. Create Variable Group in ADO Project with name vg-bckstg-[project-name]
3. Link KV to Variable Group
4. Create AKS GitOps Platform (monitoring stack, metric server, ingress, argocd, azure-devops-agent)
  - AKS name: aks-[project-name]
    > [!NOTE] 
    > Each team will have its own GitOps Platform to host their solution and apps
5. Create project-scoped Agent Pool. User created an empty org-scoped agent pool manually, so the template need to create a agent pool from the existed org-scoped which is already configured in step 4.
6. Create Azure Container Registry
   1. ACR name: acr-[project-name]


## Next steps
- [ ] Create templates
  - [ ] ACR
  - [ ] KV
  - [ ] AKS
  - [ ] Relational Posgres Database
  - [ ] Variable Group
- [ ] Create GitOps Platform template
- [ ] Integrate SonarQube (project creation if possible and scan)
  - [ ] Install SonarQube Plugin
- [ ] Install Kyverno plugin on backstage
- [ ] Ensure naming patterns (akv-xxx, acr-xxx)

### About Resource Access
- Feature: One user from project A cant be able to deploy their app in Cluster from project B.
- Feature: Project A can only have one or more GitOps Clusters. When creating Project A app, it should only lists the clusters from Project A
- Everyone can view others projects but no edits
- Every project should implement their own control access and control who can access it. Platform team must not be responsible for each project secutiry
  - Every project should have one or more DevOps Engineers/Platform Engineers/SREs in their disposal to support the project needs