---
title: Legacy Dev Container Bootstrap Archive
description: Historical record of the retired Dev Container bootstrap and documentation model.
---

## Purpose

This document archives the Dev Container setup that was active before the
layered rebuild described in [docs/plans/devcontainer-rebuild-plan.md](../../docs/plans/devcontainer-rebuild-plan.md).

The archived setup remains in the repository for reference, diagnosis, and
incremental migration work. It is no longer the active supported bootstrap
path.

## Archived Operating Model

The retired setup combined several responsibilities into one active path:

* base image selection and Dev Container features
* global CLI installation in the container
* user-home configuration materialization
* agent-host runtime wiring
* Git identity projection from the host
* environment diagnosis through a single repo entry point

That model worked, but it mixed layers that the rebuild plan now treats
separately.

## Archived Pieces

### `.devcontainer/devcontainer.json`

* What it did: defined the base .NET image, enabled
  Docker-outside-of-Docker and Node features, mounted host `~/.gitconfig`, and
  ran both post-create scripts automatically
* Responsibility: container baseline plus bootstrap trigger
* Why it was retired: it coupled the active container definition to legacy
  runtime projection and bootstrap behavior
* Planned replacement: Layer 1 for the base container, then later layers for
  anything beyond that

### `.devcontainer/post-create.sh`

* What it did: installed pinned CLIs, normalized portable Git identity
  settings, and verified the base toolchain
* Responsibility: base tooling, partial runtime setup, and some host-derived
  Git projection
* Why it was retired: it combined image-adjacent concerns, repo-local tooling,
  and runtime projection in one script
* Planned replacement: Layer 1 for the minimal baseline, Layer 2 for
  repo-local tooling, and Layer 4 for `HOME` projection

### `.devcontainer/post-create-host-setup.sh`

* What it did: installed global skills, wrote Codex, OpenCode, and VS Code
  Copilot host wiring, and synchronized user-home paths
* Responsibility: runtime integrations and user-home materialization
* Why it was retired: it wrote directly into user-home state as part of the
  active default path, which the rebuild now isolates as a later layer
* Planned replacement: Layer 3 for runtime integrations and Layer 4 for
  `HOME` projection

### `.devcontainer/doctor.sh`

* What it did: checked tool availability, runtime wiring, Git identity, and
  auth hints through a single command
* Responsibility: cross-layer diagnostics
* Why it was retired: it diagnosed the full legacy stack instead of a clearly
  bounded supported baseline
* Planned replacement: Layer 5 after the earlier layers define what the
  supported baseline actually is

### `.devcontainer/README.md`

* What it did: described the full legacy bootstrap, included tooling
  inventory, and documented validation and follow-up commands
* Responsibility: user-facing active setup guide
* Why it was retired: it described the retired bootstrap as the current
  supported flow
* Planned replacement: a new active guide for the rebuild, with this archive
  preserving historical details

### `README.md`

* What it did: pointed readers to the active Dev Container guide and the legacy
  `just` surface
* Responsibility: repository entry point for setup guidance
* Why it was retired: it routed readers into the retired bootstrap instead of
  the rebuild status
* Planned replacement: a smaller active entry point that links to the rebuild
  plan and this archive

### `Justfile`

* What it did: exposed `doctor`, `lint-md`, and container HTML serving helpers
* Responsibility: stable command surface over the legacy diagnostics
* Why it was retired: its `doctor` target invoked the retired diagnostic model
* Planned replacement: Layer 5 will define the new long-term command surface

## Legacy Tooling Inventory

The retired base bootstrap installed these pinned tools as part of the active
container lifecycle:

* Aspire CLI `13.4.5`
* GitHub Copilot CLI `1.0.63`
* OpenCode CLI `1.17.7`
* Codex CLI `0.140.0`
* Context Mode CLI `1.0.162`
* GitNexus CLI `1.6.7`
* GitHub CLI `2.95.0`
* Gentle AI CLI `1.40.2`
* Engram CLI `1.16.3`
* GGA CLI `2.8.1`
* markdownlint-cli2 `0.22.1`
* CSharpier `1.3.0`
* Biome `2.5.0`
* opensrc CLI `0.7.2`
* Skills CLI `1.5.11`
* just `1.43.1`

Those version pins are preserved here because they matter for migration and
diagnosis, even though they are no longer installed by the active Dev Container
definition.

## Legacy Behavior Worth Preserving

The retired setup established several behaviors that still matter as migration
inputs:

* Host Git identity was projected into the container through a sanitized include
  instead of copying the full host config.
* Runtime integrations were treated as user-scoped state under `/home/vscode`.
* Authentication and credential-dependent steps stayed manual.
* Tool versions were pinned explicitly instead of following floating latest
  channels.
* Validation emphasized operational sufficiency rather than exact host equality.

## Lessons And Risks

The rebuild plan retired this active path because it exposed several structural
risks:

* The base container definition and runtime integrations evolved together
  instead of as separate layers.
* Automatic `HOME` writes made the supported path harder to reason about and
  harder to classify by responsibility.
* The diagnostic surface grew to reflect the entire ecosystem rather than a
  minimal supported baseline.
* Adding one more tool tended to reopen the same bootstrap design questions.

These lessons are the reason the repository now rebuilds the setup layer by
layer instead of extending the legacy flow.

## Archive Usage

Use this archive when you need to:

* understand what the retired setup did
* migrate one responsibility into a new layer
* diagnose behavior that still originates in the legacy scripts
* recover an older workflow from git history intentionally

Do not treat this archive as the active supported setup contract.
