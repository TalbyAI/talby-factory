---
title: Dev Container Layer 1 Baseline
description: Active setup guide for the rebuilt Layer 1 Dev Container baseline.
---

## Layer 1 Scope

Layer 1 is the minimal supported Dev Container baseline for this repository.
It intentionally covers only foundational tooling and diagnostics:

* the active Dev Container definition in `.devcontainer/`
* `node` and `pnpm` from the Dev Container feature contract
* `just` from the repo-owned image layer
* a minimal root `package.json`
* a bounded root `Justfile`
* a diagnostic-only `scripts/doctor.mjs`

Layer 1 explicitly does not cover runtime integrations, `HOME` projection,
agent wiring, authentication state, or any other cross-layer bootstrap logic.

## Current Baseline

The active Layer 1 baseline is declared through these repo-owned files:

* Image or base environment tooling:
  `.devcontainer/devcontainer.json` and `.devcontainer/Dockerfile` define the
  supported container baseline and install workspace-independent base tooling.
* Repo-local tooling:
  `package.json`, `Justfile`, and `scripts/doctor.mjs` expose the bounded
  command surface and Layer 1 diagnostics.
* Runtime integrations:
  None in Layer 1. They are deferred to a later layer by design.
* `HOME` projections:
  None in Layer 1. They are deferred to a later layer by design.
* Manual or credential-dependent steps:
  Dev Container rebuild or reopen is required to materialize image-time
  changes in the running environment.

## Supported Commands

Layer 1 exposes a deliberately narrow public surface:

```bash
pnpm doctor
just check-md
just fix-md
just doctor
just --list
```

`doctor` diagnoses only the Layer 1 baseline. It does not mutate the
environment, install missing tools, or attempt runtime integration repair.

## Validation Model

Use these checks for the current Layer 1 baseline:

```bash
node -e "JSON.parse(require('fs').readFileSync('.devcontainer/devcontainer.json','utf8'))"
node --version
pnpm --version
just check-md
pnpm doctor
just --list
```

Expected behavior:

* `just check-md` lints the supported `docs/` and `.devcontainer/` Markdown
  surface with the root `.markdownlint-cli2.yaml` configuration
* `pnpm doctor` reports only Layer 1 findings
* missing `just` in an already-running container is a rebuild signal, not a
  runtime integration failure
* `just --list` succeeds after the Dev Container is rebuilt or reopened from
  the repo-declared image path

## Rebuild Requirement

The repository now declares `just` through `.devcontainer/Dockerfile`. Existing
containers created before that image change will not have `just` until the Dev
Container is rebuilt or reopened.

Until that rebuild happens, these behaviors are expected:

* `node --version` and `pnpm --version` can pass in the current session
* `pnpm doctor` can run and report a bounded warning that `just` is missing
* `just --list` can fail with `command not found`

This is a Layer 1 validation blocker, not a reason to reintroduce lifecycle
bootstrap logic.

## Git config portability note

When the container inherits a global Git config created on Windows, Git can emit
repeated warnings for `safe.directory` entries such as `C:/...` or `E:/...`
because those paths are not absolute in Linux.

The active Dev Container lifecycle handles that case through
`.devcontainer/sanitize-git-config.sh`, which runs from both
`.devcontainer/post-create.sh` and `.devcontainer/post-start.sh`.

The sanitizer removes Windows-only `safe.directory` entries from
`/home/vscode/.gitconfig` while leaving valid Linux entries intact. This keeps
`git status` and other Git commands quiet inside the supported container
baseline without reintroducing the legacy host Git projection model.

## Deferred Work

The following concerns are intentionally deferred beyond Layer 1:

* runtime integrations and agent hosts
* `HOME` projection and user-scoped config writes
* authentication-dependent setup
* broader setup or repair workflows

The Markdown lint configuration is repo-owned, currently scoped to `docs/` and
`.devcontainer/`, and assumes the Dev Container image provides
`markdownlint-cli2`.

For the retired mixed-responsibility bootstrap model and its replacement
mapping, see `.devcontainer/archive/legacy-bootstrap.md`.

For the broader tooling state, including installed-but-unsupported CLIs and
remaining work from the archived bootstrap, see
`.devcontainer/tooling-inventory.md`.
