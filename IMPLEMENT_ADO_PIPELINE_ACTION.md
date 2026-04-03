# Implement `azure:pipeline:create-and-run` Custom Scaffolder Action

## Context

This Backstage instance uses the **new backend system** (`createBackend()` pattern in `packages/backend/src/index.ts`). The Backstage version is **1.49.x**. The backend already has `@backstage/plugin-scaffolder-backend-module-azure` registered (providing `publish:azure`).

The following packages are available as **transitive dependencies** (no npm install needed):
- `@backstage/plugin-scaffolder-node` — provides `createTemplateAction`, `scaffolderActionsExtensionPoint`
- `@backstage/integration` — provides `ScmIntegrations`, `DefaultAzureDevOpsCredentialsProvider`
- `@backstage/backend-plugin-api` — provides `createBackendModule`, `coreServices`

---

## Goal

The Backstage scaffolder template `ado/react-ts-app/template.yaml` contains a step that calls this custom action:

```yaml
- id: create-pipeline
  name: Create and Trigger Azure Pipeline
  action: azure:pipeline:create-and-run
  input:
    organization: ${{ parameters.repoUrl | parseRepoUrl | pick('owner') }}
    project: ${{ parameters.ado_project }}
    repoName: ${{ parameters.repoUrl | parseRepoUrl | pick('repo') }}
    pipelineName: ${{ parameters.component_id }}-cicd
    pipelineYamlPath: /azure-pipelines.yml
```

After `publish:azure` creates the repository in Azure DevOps, this action must automatically:
1. Create the pipeline definition pointing at the `azure-pipelines.yml` file in the new repo
2. Trigger the first pipeline run

Without this action the user would have to manually click "Create pipeline" in the Azure DevOps UI.

---

## Implementation

### Step 1 — Create `packages/backend/src/extensions/azurePipelineAction.ts`

```typescript
import {
  createTemplateAction,
  scaffolderActionsExtensionPoint,
} from '@backstage/plugin-scaffolder-node';
import {
  ScmIntegrations,
  DefaultAzureDevOpsCredentialsProvider,
} from '@backstage/integration';
import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';

function createAzurePipelineAction(integrations: ScmIntegrations) {
  const credentialsProvider =
    DefaultAzureDevOpsCredentialsProvider.fromIntegrations(integrations);

  return createTemplateAction({
    id: 'azure:pipeline:create-and-run',
    description:
      'Creates an Azure DevOps pipeline from a YAML file in the repo and triggers its first run',
    schema: {
      // IMPORTANT: Backstage 1.49.x requires per-field functions, NOT z.object({...})
      input: {
        organization: (z: any) => z.string().describe('Azure DevOps Organization name'),
        project: (z: any) => z.string().describe('Azure DevOps Project name'),
        repoName: (z: any) => z.string().describe('Repository name'),
        pipelineName: (z: any) => z.string().describe('Name to give the pipeline'),
        pipelineYamlPath: (z: any) =>
          z.string().default('/azure-pipelines.yml')
            .describe('Path to the pipeline YAML file inside the repo'),
      },
      output: {
        pipelineId: (z: any) => z.number().describe('Created pipeline ID'),
        pipelineUrl: (z: any) => z.string().describe('Pipeline web URL'),
        runId: (z: any) => z.number().describe('Triggered run ID'),
        runUrl: (z: any) => z.string().describe('Run web URL'),
      },
    },

    async handler(ctx) {
      const { organization, project, repoName, pipelineName, pipelineYamlPath } =
        ctx.input as {
          organization: string;
          project: string;
          repoName: string;
          pipelineName: string;
          pipelineYamlPath: string;
        };

      const orgUrl = `https://dev.azure.com/${organization}`;

      // Reads PAT from integrations.azure[].token in app-config automatically
      const credentials = await credentialsProvider.getCredentials({
        url: `${orgUrl}/${project}`,
      });
      if (!credentials) {
        throw new Error(
          `No Azure DevOps credentials found for ${orgUrl}. ` +
            'Ensure integrations.azure is configured with a PAT token in app-config.',
        );
      }

      const authHeader =
        credentials.type === 'pat'
          ? `Basic ${Buffer.from(`:${credentials.token}`).toString('base64')}`
          : `Bearer ${credentials.token}`;

      const apiBase = `${orgUrl}/${project}/_apis`;

      // Step 1: Resolve repository ID by name
      ctx.logger.info(`Looking up repository "${repoName}" in project "${project}"…`);
      const reposRes = await fetch(`${apiBase}/git/repositories?api-version=7.0`, {
        headers: { Authorization: authHeader },
      });
      if (!reposRes.ok) {
        throw new Error(`Failed to list repositories: ${reposRes.status} ${await reposRes.text()}`);
      }
      const reposBody = (await reposRes.json()) as { value: { id: string; name: string }[] };
      const repo = reposBody.value.find(r => r.name === repoName);
      if (!repo) {
        throw new Error(
          `Repository "${repoName}" not found in project "${project}". ` +
            `Available: ${reposBody.value.map(r => r.name).join(', ')}`,
        );
      }

      // Step 2: Create the pipeline definition
      ctx.logger.info(`Creating pipeline "${pipelineName}"…`);
      const createRes = await fetch(`${apiBase}/pipelines?api-version=7.0`, {
        method: 'POST',
        headers: { Authorization: authHeader, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: pipelineName,
          configuration: {
            type: 'yaml',
            path: pipelineYamlPath,
            repository: { id: repo.id, name: repoName, type: 'azureReposGit' },
          },
        }),
      });
      if (!createRes.ok) {
        throw new Error(`Failed to create pipeline: ${createRes.status} ${await createRes.text()}`);
      }
      const pipeline = (await createRes.json()) as { id: number; _links: { web: { href: string } } };
      ctx.logger.info(`Pipeline created — ID: ${pipeline.id}`);

      // Step 3: Trigger the first run
      ctx.logger.info(`Triggering pipeline run…`);
      const runRes = await fetch(`${apiBase}/pipelines/${pipeline.id}/runs?api-version=7.0`, {
        method: 'POST',
        headers: { Authorization: authHeader, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resources: { repositories: { self: { refName: 'refs/heads/main' } } },
        }),
      });
      if (!runRes.ok) {
        throw new Error(
          `Pipeline created (ID: ${pipeline.id}) but failed to trigger run: ` +
            `${runRes.status} ${await runRes.text()}`,
        );
      }
      const run = (await runRes.json()) as { id: number; _links: { web: { href: string } } };
      ctx.logger.info(`Pipeline run triggered — Run ID: ${run.id}`);

      ctx.output('pipelineId', pipeline.id);
      ctx.output('pipelineUrl', pipeline._links.web.href);
      ctx.output('runId', run.id);
      ctx.output('runUrl', run._links.web.href);
    },
  });
}

export const scaffolderModuleAzurePipeline = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'azure-pipeline',
  register(reg) {
    reg.registerInit({
      deps: {
        scaffolderActions: scaffolderActionsExtensionPoint,
        rootConfig: coreServices.rootConfig,
      },
      async init({ scaffolderActions, rootConfig }) {
        const integrations = ScmIntegrations.fromConfig(rootConfig);
        scaffolderActions.addActions(createAzurePipelineAction(integrations));
      },
    });
  },
});

// Default export required by backend.add(import('./extensions/azurePipelineAction'))
export default scaffolderModuleAzurePipeline;
```

---

### Step 2 — Register in `packages/backend/src/index.ts`

Add this line immediately after the existing Azure scaffolder module line:

```typescript
backend.add(import('@backstage/plugin-scaffolder-backend-module-azure'));
backend.add(import('./extensions/azurePipelineAction')); // <-- add this
```

---

## Action Inputs Reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `organization` | string | ✅ | — | ADO org name (e.g. `Zenardi`) |
| `project` | string | ✅ | — | ADO project name (e.g. `Marketing`) |
| `repoName` | string | ✅ | — | Repository name (must already exist in ADO) |
| `pipelineName` | string | ✅ | — | Name to give the new pipeline |
| `pipelineYamlPath` | string | ❌ | `/azure-pipelines.yml` | Path to pipeline YAML inside the repo |

## Action Outputs Reference

| Field | Type | Description |
|---|---|---|
| `pipelineId` | number | Created pipeline ID |
| `pipelineUrl` | string | Link to pipeline in Azure DevOps UI |
| `runId` | number | ID of the triggered run |
| `runUrl` | string | Link to the triggered run in Azure DevOps UI |

---

## Prerequisites

The `app-config.yaml` (or `app-config.local.yaml`) must have a PAT-based Azure integration:

```yaml
integrations:
  azure:
    - host: dev.azure.com
      token: ${AZURE_DEVOPS_TOKEN}
```

> ⚠️ The service-principal `credentials` block (clientId/clientSecret/tenantId) does **not** work for pipeline creation — the ADO API returns `TF401444` unless the service principal has been manually provisioned in the ADO org. Use a PAT.

---

## Verification

After implementing:

```bash
# 1. Type-check — must produce zero errors for the new file
yarn tsc --noEmit

# 2. Restart the backend
yarn dev

# 3. Confirm the action is registered
curl http://localhost:7007/api/scaffolder/v2/actions | grep azure:pipeline
```

Expected output from step 3:
```json
{ "id": "azure:pipeline:create-and-run", ... }
```

---

## Known Gotchas

- **Schema format**: Backstage 1.49.x `createTemplateAction` does NOT accept `z.object({...})` directly. Each field must be `(z: any) => z.string()` etc.
- **Default export**: The module file must `export default` the result of `createBackendModule(...)` for `backend.add(import('./...'))` to work.
- **PAT encoding**: ADO expects the PAT as `Basic base64(:<token>)` — note the colon prefix before the token (no username).
- **Repo must exist first**: The action resolves the repo ID from its name; it will fail if called before `publish:azure` completes.
