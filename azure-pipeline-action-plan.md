# Custom Scaffolder Action: `azure:pipeline:create-and-run`

> Implementation prompt for the Backstage project. Apply this in the Backstage repo
> (`platform-cli/backstage-v1.49.3`) to enable the ADO React template to automatically
> create and trigger an Azure DevOps pipeline after the repo is published.

---

## Context

The Backstage instance uses the **new backend system** (`createBackend()` pattern in
`packages/backend/src/index.ts`). Backstage version: **1.49.x**.

The backend already has `@backstage/plugin-scaffolder-backend-module-azure` registered
(providing `publish:azure`). No additional `npm install` is needed — the following
packages are available as transitive dependencies:

| Package | Used for |
|---|---|
| `@backstage/plugin-scaffolder-node` | `createTemplateAction`, `scaffolderActionsExtensionPoint` |
| `@backstage/integration` | `ScmIntegrations`, `DefaultAzureDevOpsCredentialsProvider` |
| `@backstage/backend-plugin-api` | `createBackendModule`, `coreServices` |

---

## Step 1 — Create `packages/backend/src/extensions/azurePipelineAction.ts`

The action performs 3 sequential Azure DevOps REST API calls:

1. `GET /git/repositories` → resolve repo name → repo `id`
2. `POST /pipelines` → create pipeline definition pointing at the YAML file
3. `POST /pipelines/{id}/runs` → trigger first run on `refs/heads/main`

### Full implementation

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
      // ⚠️  Backstage 1.49.x requires per-field functions, NOT z.object({...})
      input: {
        organization: (z: any) => z.string().describe('Azure DevOps Organization name'),
        project:      (z: any) => z.string().describe('Azure DevOps Project name'),
        repoName:     (z: any) => z.string().describe('Repository name'),
        pipelineName: (z: any) => z.string().describe('Name to give the pipeline'),
        pipelineYamlPath: (z: any) =>
          z.string().default('/azure-pipelines.yml')
            .describe('Path to the pipeline YAML file inside the repo'),
      },
      output: {
        pipelineId:  (z: any) => z.number().describe('Created pipeline ID'),
        pipelineUrl: (z: any) => z.string().describe('Pipeline web URL'),
        runId:       (z: any) => z.number().describe('Triggered run ID'),
        runUrl:      (z: any) => z.string().describe('Run web URL'),
      },
    },

    async handler(ctx) {
      const { organization, project, repoName, pipelineName, pipelineYamlPath } =
        ctx.input;

      const orgUrl = `https://dev.azure.com/${organization}`;

      // Reads the PAT from integrations.azure[].token in app-config
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

      // 1. Resolve the repository ID
      ctx.logger.info(`Looking up repository "${repoName}" in project "${project}"…`);
      const reposRes = await fetch(
        `${apiBase}/git/repositories?api-version=7.0`,
        { headers: { Authorization: authHeader } },
      );
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

      // 2. Create the pipeline definition
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
      const pipeline = (await createRes.json()) as {
        id: number;
        _links: { web: { href: string } };
      };
      ctx.logger.info(`Pipeline created — ID: ${pipeline.id}`);

      // 3. Trigger the first run
      ctx.logger.info(`Triggering pipeline run…`);
      const runRes = await fetch(
        `${apiBase}/pipelines/${pipeline.id}/runs?api-version=7.0`,
        {
          method: 'POST',
          headers: { Authorization: authHeader, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            resources: { repositories: { self: { refName: 'refs/heads/main' } } },
          }),
        },
      );
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

## Step 2 — Register in `packages/backend/src/index.ts`

Add **one line** after the existing Azure scaffolder module line:

```typescript
backend.add(import('@backstage/plugin-scaffolder-backend-module-azure'));
backend.add(import('./extensions/azurePipelineAction')); // ← add this
```

---

## Action inputs reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `organization` | string | ✅ | — | ADO org name (e.g. `Zenardi`) |
| `project` | string | ✅ | — | ADO project name (e.g. `Marketing`) |
| `repoName` | string | ✅ | — | Repo name (must already exist in ADO) |
| `pipelineName` | string | ✅ | — | Display name for the new pipeline |
| `pipelineYamlPath` | string | — | `/azure-pipelines.yml` | Path to pipeline YAML inside repo |

## Action outputs reference

| Field | Type | Description |
|---|---|---|
| `pipelineId` | number | Numeric ID of the created pipeline |
| `pipelineUrl` | string | Web URL to the pipeline in ADO |
| `runId` | number | Numeric ID of the triggered run |
| `runUrl` | string | Web URL to the triggered run in ADO |

---

## How it is called from the template

`ado/react-ts-app/template.yaml` calls this action as the last step:

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

---

## Verification

```bash
# 1. Type-check — must produce zero errors in the new file
yarn tsc --noEmit

# 2. Restart backend
yarn dev

# 3. Confirm action is registered
curl -s http://localhost:7007/api/scaffolder/v2/actions \
  | grep -o '"azure:pipeline:create-and-run"'
# Expected output: "azure:pipeline:create-and-run"
```
