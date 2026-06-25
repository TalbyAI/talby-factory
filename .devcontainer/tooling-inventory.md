---
title: Dev Container Tooling Inventory
description: Inventory of active tooling, deferred runtime integrations, and remaining setup work for the rebuilt dev container.
---

## Purpose

This inventory separates the current supported dev container baseline from the
broader toolchain that exists in the image or remains to be reintroduced from
the archived bootstrap.

Use this file when you need to answer one of these questions:

* What is officially supported today?
* Which CLIs are already present in the image?
* Which pieces from the archived setup are still not configured?

## Supported Today

The active supported setup is Layer 1 only.

Layer 1 covers:

* the dev container definition in `.devcontainer/`
* `node` and `pnpm`
* `just`
* the root `package.json`
* the root `Justfile`
* the bounded `pnpm doctor` diagnostic

For the active support contract, see `docs/plans/setup-dev-container.md`.

## Installed In The Current Image

These tools are declared in `.devcontainer/Dockerfile` and available in the
current container image, even when Layer 1 does not document or validate them
yet as part of the supported baseline.

### Base environment tooling

* `node`
* `pnpm`
* `just`
* `docker`
* `az`
* `gh`
* `ripgrep`

### Developer CLIs already installed

* `aspire`
* `codex`
* `opencode`
* `context-mode`
* `gitnexus`
* `markdownlint-cli2`
* `biome`
* `opensrc`
* `skills`
* `csharpier`

## Not Yet Configured For The Current Setup

These items were part of the archived mixed-responsibility bootstrap or were
tracked as follow-up work, but they are not materialized by the current active
dev container lifecycle.

### Runtime integrations not restored yet

* Context Mode hook wiring for Codex and VS Code Copilot
* MCP wiring for Codex, OpenCode, and VS Code
* Global skills installation for Codex, GitHub Copilot, and OpenCode
* OpenCode skill synchronization from the shared global skills path

### Tooling still missing from the rebuilt lifecycle

* `engram` CLI
* `gentle-ai` CLI
* `gga` CLI

### Pending plugin and host setup work

* `ponytail` plugin checkout and pinning
* `ponytail` plugin registration for Codex
* `ponytail` plugin registration for GitHub Copilot CLI
* `ponytail` plugin registration for OpenCode
* idempotent `.opencode/command/*` projection into user `HOME`

### Documentation still pending

* Final expanded dev container README for post-Layer-1 tooling
* Authentication notes for tools that require login or consent
* Verification commands for the runtime integration layer

## What The Active Lifecycle Does Today

The current active lifecycle is intentionally narrow:

* `.devcontainer/Dockerfile` builds the container image and installs pinned base
  tooling plus several developer CLIs
* `.devcontainer/post-create.sh` only ensures persistent directory ownership,
  writes pnpm user config, and sanitizes Git config
* `.devcontainer/post-start.sh` only reruns Git config sanitization

The archived host setup script is retained for reference only. It is not part
of the active supported path.

## References

* Active Layer 1 guide: `docs/plans/setup-dev-container.md`
* Rebuild plan: `docs/plans/devcontainer-rebuild-plan.md`
* Archived bootstrap map: `.devcontainer/archive/legacy-bootstrap.md`
* Archived host setup logic: `.devcontainer/archive/post-create-host-setup.sh`
