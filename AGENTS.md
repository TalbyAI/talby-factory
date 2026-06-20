# AGENTS.md

## Purpose

This repository is currently a DevContainer and agent-tooling workspace, not an
application codebase. Optimize for small, explicit changes to container
bootstrap, agent setup, and documentation.

## Source Of Truth

- Start at [README.md](./README.md) for repo scope.
- Use [.devcontainer/README.md](./.devcontainer/README.md) as the primary guide
  for container behavior, installed tools, manual follow-up steps, and
  verification commands.
- Use [docs/plans/setup-dev-container.md](./docs/plans/setup-dev-container.md)
  for historical decisions and the incremental tooling rollout checklist.
- Repo-scoped Engram identity is pinned in
  [.engram/config.json](./.engram/config.json).

## Working Model

- Treat `.devcontainer/post-create.sh` as the main bootstrap entry point.
- Treat `.devcontainer/post-create-host-setup.sh` as optional host-level setup,
  not baseline repo bootstrap.
- Prefer updating docs when changing bootstrap behavior. In this repo, code and
  documentation are tightly coupled.
- Keep version changes explicit and pinned. Do not silently switch install
  channels or introduce floating latest-version behavior.

## Validation

- There is no general app test suite yet. Validate the narrowest affected
  workflow instead of inventing broad checks.
- For bootstrap changes, prefer targeted command checks and the documented
  version probes from [.devcontainer/README.md](./.devcontainer/README.md).
- For Markdown changes, run `markdownlint-cli2` when the container tooling is
  available.
- If you change both bootstrap behavior and docs, verify both in the same pass.

## Repo-Specific Gotchas

- GGA is initialized in this repo through [.gga](./.gga) and points
  `RULES_FILE` to this root `AGENTS.md`. Changes here affect both chat guidance
  and GGA review behavior.
- The current GGA review scope is limited to `*.ts`, `*.tsx`, `*.js`, `*.jsx`,
  and `*.cs`, with common test/spec files excluded. If the repo starts
  reviewing other file types, update [.gga](./.gga) intentionally.
- Engram project resolution should stay `talby-factory`. If project-scoped
  memory starts resolving elsewhere, verify `.engram/config.json` before saving
  new observations.
- Host browsers cannot open container-only paths through `file:///home/vscode/...`.
  When an agent needs to open HTML generated inside the container, use
  `just open-html root=/path/in/container file=name.html` and then open the reported
  `http://127.0.0.1:<port>/...` URL instead.

## Existing Host-Specific Instructions

- [.codex/AGENTS.md](./.codex/AGENTS.md) contains Codex host behavior and
  persona rules.
- [.config/opencode/AGENTS.md](./.config/opencode/AGENTS.md) contains OpenCode
  host behavior and persona rules.
- Keep this root file repo-specific. Do not duplicate host-persona instructions
  here unless they become repository conventions.

## Editing Guidelines

- Prefer minimal diffs and preserve the current documentation style.
- Link to existing docs instead of copying long procedures into new files.
- When adding a new tool or setup flow, document:
  - install channel
  - pinned version
  - verification command
  - whether auth or manual follow-up is required
  - whether the change belongs in base bootstrap or optional host setup
