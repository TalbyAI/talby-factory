---
title: Dev Container Guide
description: Active Dev Container status and migration guidance for the talby-factory repository.
---

## Status

The repository is in the middle of the Dev Container rebuild described in
[docs/plans/devcontainer-rebuild-plan.md](../docs/plans/devcontainer-rebuild-plan.md).

The legacy bootstrap has been archived and removed from the active supported
path. The current active container definition is intentionally minimal while the
new layered setup is rebuilt.

## Active Container Surface

The current supported active definition includes only:

* the base .NET Dev Container image
* Docker outside-of-Docker support
* the pinned Node.js and pnpm feature
* the VS Code extension and terminal settings declared in
  `.devcontainer/devcontainer.json`

The active container no longer runs repo-owned post-create bootstrap scripts,
does not project host Git configuration automatically, and does not claim a
fully rebuilt `doctor` command yet.

## Historical Archive

Use the archive when you need the retired setup details:

* The old active path, its implementation details, and its helper programs live
  under `.devcontainer/archive/`.
* Archive contents are for migration and diagnosis only. They are not part of
  the active supported bootstrap contract.

## Validation Expectations

At this stage of the rebuild, validation is limited to the active container
definition and the associated documentation. The old bootstrap checks were part
of the retired setup and should not be treated as active requirements.

## Next Step

The next implementation milestone is Layer 1 from the rebuild plan: a minimal,
repo-driven baseline with a new operational manifest, a new bounded `doctor`,
and explicit layer-scoped setup commands.
