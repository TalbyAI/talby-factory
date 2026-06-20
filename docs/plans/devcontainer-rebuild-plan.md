---
title: Dev Container Rebuild Plan
description: Layered migration plan for replacing the current Dev Container
  bootstrap with a cleaner, repo-driven setup model.
---

## Goal

Rebuild the supported Dev Container setup from a clean baseline,
replacing the current active bootstrap path with a layered model that
is easier to understand, diagnose, and evolve.

This plan does not implement the migration. It captures the decisions
already made so implementation can proceed incrementally without
reopening the same design questions.

## Planning Outcome

The problem is not only whether to use a `Dockerfile`. The deeper
issue is the current mixing of responsibilities between:

- image construction
- global environment tooling
- repo-local tooling
- runtime integrations for agent hosts
- projections into user `HOME`
- diagnosis and explicit setup commands

The migration will therefore be designed by layers and
responsibilities first. The final use of a `Dockerfile` remains a
design consequence, not a fixed premise.

## Supported Operating Model

- The only officially supported working environment is the Dev Container.
- Local non-container setups may exist, but they are not the supported baseline.
- The Dev Container baseline is the reference environment for
  diagnostics, documentation, and support.

## Decisions Already Made

### 1. Source of truth

- The repository is the declarative source of truth.
- User `HOME` inside the container is only a runtime destination when a
  tool requires it.
- Configuration should be versioned in the repository whenever practical.
- `HOME` should not be treated as the primary authoring surface.

### 2. Setup model

- The current setup will be archived as historical documentation only.
- It will not remain an active fallback path during the migration.
- Rollback, if needed, should come from git history rather than from
  keeping two live setup systems in parallel.

### 3. Migration strategy

- The new setup will be rebuilt from a clean active path.
- Migration will proceed layer by layer, not tool by tool.
- Each new layer must provide minimum functional parity for its
  essential use case.
- Each new layer must also improve the structure of the system:
  clearer ownership, lower fragility, and better diagnostics.

### 4. Tool placement hierarchy

- Repo-local tools are preferred for project tooling and repo-owned
  automation.
- Global/container-level tools are reserved for base runtimes, system
  utilities, and environment foundations.
- Agent hosts and their integrations are treated as runtime
  environment integrations, not as ordinary project-local tools.
- Tools are classified by responsibility before deciding where they are installed.

### 5. `Dockerfile` status

- A `Dockerfile` is not yet a committed architectural premise.
- It remains an option to evaluate after classifying responsibilities.
- The first design task is deciding what belongs in the image, what
  belongs in repo manifests, what belongs in runtime setup, and what
  must be projected into `HOME`.

### 6. Installation channels

- Official installation channels are preferred per tool.
- A single uniform installation mechanism will not be forced across all tools.
- The preferred order is:
  - Dev Container features or image-level mechanisms for base platform
    concerns
  - official package managers such as `apt`, `npm`, `pnpm`, or `.NET
    tool` manifests when appropriate
  - official provider scripts when they are stable and non-interactive
  - direct binary downloads only as a last resort

### 7. Repo-local manifests

- The main operational manifest should live at repository root.
- If the setup runtime remains Node.js, the primary manifest should be `package.json`.
- `.NET tool` manifests should be used only for tools that clearly
  belong to the .NET ecosystem.
- The same responsibility should not be duplicated across npm and
  `.NET tool` manifests.
- The initial `package.json` for Layer 1 should be deliberately
  minimal and contain only what is required to run `doctor` and its
  immediate support logic.

Node.js is the chosen runtime for the `doctor` system and its
repo-owned support logic.

### 8. Command contract

- `doctor` is the only generic diagnostic command.
- `doctor` only diagnoses, classifies, and explains.
- `doctor` must not mutate the environment.
- Setup for the supported path is automatic and should be invoked by
  the Dev Container lifecycle, not by a user-facing recipe in
  `Justfile`.
- Environment materialization should happen through explicit commands
  tied to a layer or responsibility, such as dependency restore or
  setup commands with narrow scope.
- The design must avoid a generic `repair` abstraction that can grow
  into an opaque bucket of side effects.

### 9. Automation boundaries

- Explicit setup commands should automate only deterministic,
  non-sensitive, non-interactive steps.
- Any step requiring credentials, user consent, login, secrets, or
  interactive confirmation must remain manual.
- When such manual action is required, `doctor` must report it
  explicitly.

### 10. Diagnostic philosophy

- `doctor` should validate operational sufficiency and relevant drift
  from the supported baseline.
- It should not require exact machine equality.
- Findings should be classified by severity:
  - `ERROR` for missing prerequisites that break the supported baseline
  - `WARN` for meaningful drift that may still allow work
  - `INFO` for recommendations and optional improvements

### 11. Agent integration model

- Copilot, OpenCode, Codex, MCP wiring, hooks, and similar concerns
  belong to a runtime integration layer.
- They are not treated as ordinary project-local dependencies.
- Their repo-owned configuration should be declared in the repository
  where possible.
- If a host requires config files in `HOME`, those files should be
  projected there from repo-owned configuration.

## Layer Model

The migration plan will be organized around these layers.

### Layer 1. Base operational foundation

This is the first layer to rebuild.

It should include:

- the supported Dev Container baseline
- `node` and `pnpm`
- `just`
- root operational manifest, expected to be `package.json` if Node.js
  remains the runtime
- an initial `doctor`
- initial explicit setup commands for the base layer

The initial `doctor` for this layer should validate only foundational invariants:

- the environment is the supported Dev Container
- `node`, `pnpm`, and `just` are available
- the operational manifest exists and is coherent
- the repo base commands can start
- no essential prerequisite is missing for future layers
- a very small set of baseline repo files required by Layer 1 is
  present and structurally coherent

This first layer should explicitly avoid validating:

- MCP wiring
- agent hosts
- hooks
- `HOME` projections
- authentication state

### Layer 2. Repo-local project tooling

This layer covers tools that belong to the repository and should be
restored from repo-local manifests and deterministic commands.

### Layer 3. Runtime integration layer

This layer covers agent hosts, MCP servers, hook wiring, and other
runtime environment integrations required by the supported Dev
Container workflow.

### Layer 4. `HOME` projection layer

This layer materializes runtime-required config into user `HOME` only
when tools require those locations.

### Layer 5. Evolving diagnostics and setup commands

- `doctor` and explicit setup commands must evolve with each layer.
- `just` should expose the stable command surface from early in the migration.
- The setup path itself is automatic; `just` is not required to expose
  a public setup recipe unless a future debugging need justifies it.
- Node.js is the main implementation runtime for these commands, with
  shell used only for narrowly scoped system operations.

## Historical Setup Archive Requirements

The archived description of the current setup should preserve:

- what each current setup piece does
- which responsibility it currently fulfills
- why it is being retired from the active path
- which future layer is expected to replace it
- what lessons or risks were learned from the current design

The historical archive should live under `.devcontainer/archive`.

## Documentation Requirements For The New Setup

- The new README should include a categorized inventory of tools and
  integrations by setup type.
- That inventory should make it clear how future tools are expected to
  be incorporated.
- The categories should distinguish at least:
  - image or base environment tooling
  - repo-local tooling
  - runtime integrations
  - `HOME` projections
  - manual or credential-dependent steps
- The goal is to support future extension without reopening the setup
  model from scratch each time a new tool is added.

## Validation Model For Future Implementation

A new layer should be considered successful when:

- it covers the essential use case previously handled by the old setup
  for that layer
- it improves structural clarity and reduces fragility
- its `doctor` checks are explicit and understandable
- its explicit setup commands are deterministic and repo-driven
- any remaining manual actions are clearly surfaced rather than hidden

## Open Questions Still To Resolve

- Whether the final active design should use a `Dockerfile`, a
  minimized `postCreate` path, or a combination of both.
- Which current tools belong in Layer 2 versus Layer 3.
- Which existing host integrations require projection to `HOME` and
  which can remain purely repo-declared.

## Recommended Implementation Order

1. Archive the current setup as historical documentation.
2. Remove the current setup from the active design path conceptually.
3. Rebuild Layer 1 as the minimal supported baseline.
4. Add Layer 2 repo-local tooling.
5. Add Layer 3 runtime integrations.
6. Add Layer 4 `HOME` projections only where required.
7. Expand `doctor` and the explicit setup commands with each new layer.
8. Re-evaluate whether a `Dockerfile` is warranted after the
  responsibility split is proven.
