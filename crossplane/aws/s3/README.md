

```sh
# Expose variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in your environment
# export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
# export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY

# Create the secret
kubectl create secret generic aws-secret \
  --namespace=crossplane-system \
  --from-literal=credentials="[default]
aws_access_key_id=$AWS_ACCESS_KEY_ID
aws_secret_access_key=$AWS_SECRET_ACCESS_KEY"
```
# Integration with ArgoCD
In order for Argo CD to track Application resources that contain Crossplane related objects, configure it to use the annotation mechanism.

To configure it, edit the argocd-cm ConfigMap in the argocd Namespace as such:

```sh
apiVersion: v1
kind: ConfigMap
data:
  application.resourceTrackingMethod: annotation
```

## Set health status

Reference: https://docs.crossplane.io/latest/guides/crossplane-with-argo-cd/

Argo CD has a built-in health assessment for Kubernetes resources. The community directly supports some checks in Argo’s repository. For example the Provider from pkg.crossplane.io already exists which means there no further configuration needed.

Argo CD also enable customising these checks per instance, and that’s the mechanism used to provide support of Provider’s CRDs.

To configure it, edit the **argocd-cm** ConfigMap in the **argocd** Namespace.

> [!TIP]
> ProviderConfig may have no status or a status.users field.

```yaml
apiVersion: v1
kind: ConfigMap
data:
  application.resourceTrackingMethod: annotation
  resource.customizations: |
    "*.upbound.io/*":
      health.lua: |
        health_status = {
          status = "Progressing",
          message = "Provisioning ..."
        }

        local function contains (table, val)
          for i, v in ipairs(table) do
            if v == val then
              return true
            end
          end
          return false
        end

        local has_no_status = {
          "ClusterProviderConfig",
          "ProviderConfig",
          "ProviderConfigUsage"
        }

        if obj.status == nil or next(obj.status) == nil and contains(has_no_status, obj.kind) then
          health_status.status = "Healthy"
          health_status.message = "Resource is up-to-date."
          return health_status
        end

        if obj.status == nil or next(obj.status) == nil or obj.status.conditions == nil then
          if (obj.kind == "ProviderConfig" or obj.kind == "ClusterProviderConfig") and obj.status.users ~= nil then
            health_status.status = "Healthy"
            health_status.message = "Resource is in use."
            return health_status
          end
          return health_status
        end

        for i, condition in ipairs(obj.status.conditions) do
          if condition.type == "LastAsyncOperation" then
            if condition.status == "False" then
              health_status.status = "Degraded"
              health_status.message = condition.message
              return health_status
            end
          end

          if condition.type == "Synced" then
            if condition.status == "False" then
              health_status.status = "Degraded"
              health_status.message = condition.message
              return health_status
            end
          end

          if condition.type == "Ready" then
            if condition.status == "True" then
              health_status.status = "Healthy"
              health_status.message = "Resource is up-to-date."
            end
          end
        end

        return health_status

    "*.crossplane.io/*":
      health.lua: |
        health_status = {
          status = "Progressing",
          message = "Provisioning ..."
        }

        local function contains (table, val)
          for i, v in ipairs(table) do
            if v == val then
              return true
            end
          end
          return false
        end

        local has_no_status = {
          "Composition",
          "CompositionRevision",
          "DeploymentRuntimeConfig",
          "ClusterProviderConfig",
          "ProviderConfig",
          "ProviderConfigUsage"
        }
        if obj.status == nil or next(obj.status) == nil and contains(has_no_status, obj.kind) then
            health_status.status = "Healthy"
            health_status.message = "Resource is up-to-date."
          return health_status
        end

        if obj.status == nil or next(obj.status) == nil or obj.status.conditions == nil then
          if (obj.kind == "ProviderConfig" or obj.kind == "ClusterProviderConfig") and obj.status.users ~= nil then
            health_status.status = "Healthy"
            health_status.message = "Resource is in use."
            return health_status
          end
          return health_status
        end

        for i, condition in ipairs(obj.status.conditions) do
          if condition.type == "LastAsyncOperation" then
            if condition.status == "False" then
              health_status.status = "Degraded"
              health_status.message = condition.message
              return health_status
            end
          end

          if condition.type == "Synced" then
            if condition.status == "False" then
              health_status.status = "Degraded"
              health_status.message = condition.message
              return health_status
            end
          end

          if contains({"Ready", "Healthy", "Offered", "Established", "ValidPipeline", "RevisionHealthy"}, condition.type) then
            if condition.status == "True" then
              health_status.status = "Healthy"
              health_status.message = "Resource is up-to-date."
            end
          end
        end

        return health_status
```

## Set resource exclusion 
Crossplane providers generate a ProviderConfigUsage for each managed resource (MR) they handle. This resource enables representing the relationship between MR and a ProviderConfig so that the controller can use it as a finalizer when you delete a ProviderConfig. End users of Crossplane don’t need to interact with this resource.

A growing number of resources and types can impact Argo CD UI reactivity. To help keep this number low, Crossplane recommend hiding all ProviderConfigUsage resources from Argo CD UI.

To configure resource exclusion edit the **argocd-cm** ConfigMap in the **argocd** Namespace as such:

```sh
apiVersion: v1
kind: ConfigMap
data:
  resource.exclusions: |
    - apiGroups:
      - "*"
      kinds:
      - ProviderConfigUsage
```

## Increase Kubernetes client QPS 
As the number of CRDs grow on a control plane it increases the amount of queries Argo CD Application Controller needs to send to the Kubernetes API. If this is the case you can increase the rate limits of the Argo CD Kubernetes client.

Set the environment variable ARGOCD_K8S_CLIENT_QPS to 300 for improved compatibility with multiple CRDs.

The default value of ARGOCD_K8S_CLIENT_QPS is 50, modifying the value also updates ARGOCD_K8S_CLIENT_BURST as it is default to ARGOCD_K8S_CLIENT_QPS x 2.