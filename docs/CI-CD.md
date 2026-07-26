# CI/CD

## Pull-request validation

`.github/workflows/Validate.yml` runs for pull requests to `main`, pushes to
feature branches, and manual dispatches.

The workflow:

1. Installs pinned minimum versions of Pester and PSScriptAnalyzer.
2. Validates syntax, manifests, exports, private boundaries, and public help.
3. Runs the repository Pester suite.
4. Builds clean module artifacts.
5. Uploads tests and module artifacts for review.

Recommended branch protection for `main`:

- Require a pull request.
- Require the `Validate, Test, and Build` status check.
- Require one approval.
- Require the branch to be up to date.
- Block force pushes and branch deletion.

## PowerShell Gallery release

`.github/workflows/Publish-Modules.yml` is the only supported publishing path.
It runs after a merge to `main` or by manual dispatch.

The release workflow validates and tests the repository again, builds artifacts,
then compares every artifact version with PowerShell Gallery. Only newer versions
are published. Core is evaluated first and the meta-module last so dependencies
exist before dependent packages are released. Before publishing the meta-module,
the workflow waits until every required minimum version is visible in the Gallery.

Successful publications receive annotated tags in this format:

```text
OMG.PSUtilities.Core-v1.0.20
```

## Required repository secret

Create this GitHub Actions repository secret:

| Secret | Purpose |
| --- | --- |
| `PSGALLERY_API_KEY` | PowerShell Gallery API key used only by the publish step |

Use a scoped Gallery key and rotate it periodically. Never place the value in a
workflow, issue, pull request, local settings file, or repository documentation.

## Release process

1. Update the affected module CHANGELOG.
2. Increase its `ModuleVersion` according to semantic versioning.
3. Open a pull request and wait for validation.
4. Merge to `main`.
5. Confirm the publish workflow uploaded artifacts, published expected versions,
   and created release tags.

If no manifest version is newer than Gallery, the workflow succeeds without
publishing. A failed module publication fails the workflow and prevents later
modules from being published.
