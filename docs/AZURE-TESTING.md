# Azure integration testing

## Scope

PowerShell Gallery publishing does not require Azure resources. Pull-request and
release validation therefore use local tests and mocks by default. This keeps CI
fast, deterministic, and free of Azure consumption costs.

Live Azure tests are reserved for explicit manual execution against:

| Setting | Value |
| --- | --- |
| Tenant | `d4447f09-6c75-4479-8911-019da3f93632` |
| Resource group | `rg-redesign-omg-psmodules` |
| Service principal | `sp-redesign-omg-psmodules` |

No client secret is stored in this repository. Any secret previously shared in
plaintext must be rotated before further use.

## Authentication design

Use GitHub Actions OpenID Connect federation for live integration tests. Configure
an Entra federated credential for the repository and store only these non-secret
values as GitHub configuration:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The workflow should use `azure/login` with OIDC and `permissions: id-token: write`.
Do not configure `AZURE_CLIENT_SECRET`.

## Cost controls

- Reuse the dedicated resource group.
- Prefer read-only tests and mocked API calls.
- Create resources only for a specific integration scenario.
- Use free or consumption tiers where available.
- Apply tags: `project=OMG.PSUtilities`, `purpose=integration-test`, and `owner=portfolio`.
- Delete temporary resources in an `always()` cleanup step.
- Do not create VMs, AKS clusters, premium databases, or long-lived public endpoints for tests.

## Current status

The requested tenant is not available to the Azure extensions identity used during
this redesign, so no Azure resources were created or modified. The resource group
was also not visible across the subscriptions available to that identity.
