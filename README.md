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
  - [ ] Cluster Provider Config (Crossplane). Template params
```
Template params:
--- K8s Secret ---
- Service principal client Id
- Service principal secret
- Tenant
```
  - [ ] ACR
  - [ ] KV
  - [ ] AKS
  - [ ] Variable Group
  - [ ] Relational Posgres Database
- [ ] Create GitOps Platform template
- [ ] Integrate SonarQube (project creation if possible and scan)
  - [ ] Install SonarQube Plugin
- [ ] Install Kyverno plugin on backstage
- [ ] Ensure naming patterns (akv-xxx, acr-xxx)

### Implementation Plan
Create a implementation plan to build a "AKS GitOps Platform" backstage template. This template will be resposible to create AKS clusters and do a complete setup - argocd, azuredevops agents, crossplane CRDs and Cluster Proviver Config (to deploy new azure resources using crossplane), metric server, monitoring stack (grafana+prometheus), traefik for new projects. Put the working files under backstage-software-templates/ado/aks-gitops-platform folder.

To create the AKS GitOps Platform, the backstage user/developer must follow these steps:

### Step 1
Before using this template, user must create some resources manually to have GitOps Platform, and that is:
- Azure subscription
- Create Azure DevOps Organization
- Create an empty org-scoped Agent Pool on that ADO Org.
- Create PAT: ARGOCD_ADO_PAT so ArgoCD is able to sync with git code
- Create a Service Principal for Crossplane to provision resources (ClusterProviderConfig object)
  - az ad sp create-for-rbac --name "crossplane-azure-provider" --role Contributor --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> --sdk-auth > azure-credentials.json

### Step 2
Go to backstage, and fill up the "Create AKS GitOps Platform" template form with:
- Subscription ID
- ADO Org Name
- Project Name
- Org-scoped Agent Pool Name
- ArgoCD Personal Access Token create on ADO (ARGOCD_ADO_PAT)
- Owner (Group owner inside backstage)
- System or Project Responsible
- Environment
- ARGO_ADO_PAT (ADO PAT so argocd may sync code to private ADO Repos)
- ArgoCD URL (deafults to cluster local address: 'argocd-server.argocd')
- Crossplane's Service Principal Client ID
- Crossplane's Service Principal Secret
 

To create azure resources, you must implement using Crossplane (Composite Resource - XR, Composite Resource Definition - XRD, and Composition). 

The Cluster Provider Config is installed in KIND Cluster.

Using Crossplane this Template will provision:
1. Resource Group (RG) with name rg-[project-name] to put all these resources in it
2. Azure Container Registry
   - ACR name: acr-[project-name]
3. KeyVault 
  - AKV Secrets: 
    - ARGO_URL
    - ARGOCD_ADO_PAT
    - ARGOCD_PASSWORD - it should get retrieved after provision ArgoCD on new AKS Cluster by running 'kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode'
    - ACR_USERNAME
    - ACR_PASSWORD
    - Crossplane's Service Principal Client ID (CROSSPLANE_SP_PRINCIPAL_ID)
    - Crossplane's Service Principal Secret (CROSSPLANE_SP_PRINCIPAL_SECRET)
  - KV Name: kv-[project-name]-[random-4-letters-caracters]
   - 2.1 Assign Crosplane SP to have Key Vault Adminsitrator access to this AKV
4. Create a managed identity and set it as Key Vault Administrator permission on AKV
   - Managed Identity name: mi-[project-name]
5. Create a Azure DevOps Service Connection.
   - Connection Type: Azure Resource Manager
   - Identity Type: Managed Identity
   - Subscription for managed identity: Subscription ID specified in backstage template form
   - Resource group for managed identity: rg-[project-name]
   - Managed Identity: mi-[project-name]
   - Azure scope: Subscriptoin
   - Subscription for service connection: Subscription ID specified in backstage template form
   - Service Connection Name: sc-[project-name]
6. Create Variable Group in ADO Project with name vg-[project-name]
7. Link Keyvault to Variable Group by using the previous created service connection and add all secrets to variable group
8. Create AKS GitOps Platform (monitoring stack, metric server, traefik ingress, argocd, azure-devops-agent)
  - AKS name: aks-[project-name]
    > [!NOTE] 
    > Each team will have its own GitOps Platform to host their solution and apps
  - AKS Nodes sohuld be provisioned with Spot Instances and use minimal node size to have the most cost-optimal configuration. Users will be able to create new 'production-like' nodes using other backstage template in the future.
9. Create project-scoped Agent Pool. User created an empty org-scoped agent pool manually and on item 8 from above the AKS GitOps Platform provisioned the org-scoped agents, so the template need to create an agent pool from the existed org-scoped which is already configured in item 8. This way new projects are automatically ran using those project-scoped agents without issues as we already tested in 'react-ts-app' implementattion.


In KIND clster I have already created Provider family and Provider Config
```yml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: upbound-provider-family-azure
spec:
  package: xpkg.upbound.io/upbound/provider-family-azure:v2.5.2
---
apiVersion: azure.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: azure-default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials
      key: credentials
```



### About Resource Access
- Feature: One user from project A cant be able to deploy their app in Cluster from project B.
- Feature: Project A can only have one or more GitOps Clusters. When creating Project A app, it should only lists the clusters from Project A
- Everyone can view others projects but no edits
- Every project should implement their own control access and control who can access it. Platform team must not be responsible for each project secutiry
  - Every project should have one or more DevOps Engineers/Platform Engineers/SREs in their disposal to support the project needs

