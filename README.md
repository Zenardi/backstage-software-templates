# TODO

## Wave 0 - Pre-Alpha 0.0.1
- [x] EKS Template
- [x] Spring API Template
- [x] Container Registry Template
- [x] Install crossplane plugin
- [x] Test springboot-grpc template (api-docs)
- [x] Improve python-app template (too simple)
- [x] Fix ArgoCD health check of apps
  - [x] Create folder argocd in react-ts-app and adapt pipeline
  - [x] springgrpc argocd fix
- [x] Fix S3 template: 
- [x] Fix duplicate org_name field
- [x] Automate the creation of grafana charts and metrics
  - Cant push alerts, only dashboards
- [x] Add ServiceMonitor kubernetes object on templates
- [x] New Service to install ClusterProviderConfig on target cluster (remove this install from all crossplane tempaltes)

## Wave 1 - Pre-Alpha 0.0.2
- [ ] Integrate SonarQube (project creation if possible and scan)
  - [ ] Install SonarQube Plugin
- [ ] Install Kyverno plugin on backstage
- [ ] RDS Aurora Template (SQL)
- [ ] DynamoDB (NoSQL) Template
- [ ] Angular Template
- [ ] Ensure naming patterns