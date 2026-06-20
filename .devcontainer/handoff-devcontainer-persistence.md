# Dev Container Persistence Handoff

## Scope

This handoff captures the diagnosis completed so far for the
problem: after a Dev Container rebuild, Codex/Copilot
configuration and credentials appear to be lost.

The next session should focus on choosing and implementing a
persistence strategy for user-scoped state outside the
repository.

## Current Status

- Diagnosis completed.
- No repository files were changed as part of the diagnosis.
- No persistence solution has been implemented yet.

## Primary Finding

The current Dev Container setup recreates tool wiring on each
rebuild, but it does not persist the `vscode` home directory or
the agent-specific config locations written under it.

That means config can be re-seeded automatically, while
credentials and user-scoped runtime state stored only inside the
container can disappear on rebuild.

## Evidence

- `postCreateCommand` runs both bootstrap scripts on create and
   rebuild. See `./.devcontainer/devcontainer.json`.
- The only explicit mount in the container config is the host Git
   config bind mount. See `./.devcontainer/devcontainer.json`.
- User-level agent config is written under:
  - `~/.codex`
  - `~/.agents`
  - `~/.config/opencode`
  - `~/.vscode-server/data/Machine`
  - `~/.claude`
  See `./.devcontainer/post-create-host-setup.sh`.
- The repository documentation explicitly states that bootstrap
   does not persist credentials and that sign-in remains manual.
   See `./.devcontainer/README.md`.

## Key Interpretation

This does not currently look like a random bootstrap bug.

It looks like an expected consequence of the present design:

- reproducible CLI install and user-level config re-seeding via post-create scripts
- no explicit persistence layer for most of `/home/vscode`
- manual authentication flows left outside the repo

## Likely Root Cause

On rebuild, the container filesystem is recreated.

Because the repo only mounts host `~/.gitconfig` and does not
explicitly persist `/home/vscode` or the agent config
directories, any credentials or runtime state stored only in
those directories can be lost.

## Referenced Artifacts

Avoid re-summarizing the full tool rollout history; use the
existing artifacts directly:

- `./.devcontainer/README.md`
- `./docs/plans/setup-dev-container.md`
- `./.devcontainer/devcontainer.json`
- `./.devcontainer/post-create-host-setup.sh`
- `./AGENTS.md`

## Recommended Next Session Checks

Run these checks before choosing an implementation path:

1. Confirm what is really mounted versus ephemeral:
   - `findmnt -T /home/vscode`
   - `findmnt -T /home/vscode/.codex`
   - `findmnt -T /home/vscode/.vscode-server`
2. Create sentinel files before rebuild and verify what survives after rebuild:
   - one under the repo workspace
   - one under `~/.codex`
   - one under `~/.agents`
   - one under `~/.vscode-server/data/Machine`
3. Separate “config recreated” from “credentials lost”:
   - verify whether files exist after rebuild
   - verify whether the tool still considers the session authenticated

## Solution Paths To Evaluate

1. Bind-mount selected host directories into the container.
   Tradeoff: strongest persistence, highest host coupling.
2. Use Docker named volumes for selected user-state directories.
   Tradeoff: persistent across rebuilds, less visible and less portable.
3. Split reproducible config from secrets.
   Tradeoff: cleanest design, but requires more implementation discipline.
4. Keep the current model and document re-auth flows only.
   Tradeoff: lowest effort, does not solve the root problem.

## Suggested Skills

- `diagnosing-bugs`
   Useful if the next agent needs to verify whether the issue is
   true state loss or a narrower auth/runtime mismatch.
- `codebase-design`
   Useful to design a clean persistence boundary between
   repo-scoped config, user-scoped config, and secrets.
- `project-setup-info-context7`
   Useful if the next session needs current Dev Container or VS
   Code setup guidance before editing the container definition.

## Suggested Implementation Direction

If the goal is practical persistence with minimal repo pollution,
the best first candidate is usually:

- persist `~/.codex`
- persist `~/.agents`
- persist `~/.config/opencode`
- persist `~/.vscode-server/data/Machine`

and keep credentials out of repository files.

Then validate rebuild behavior with sentinel files and a real sign-in state check.

## Notes For The Next Agent

- The user explicitly asked for a persistent handoff inside the
   repository rather than a temporary OS directory.
- Use the existing lowercase `.devcontainer` directory; do not
   create a parallel `.DevContainer` directory unless the user
   asks for a rename.
- No implementation should be started blindly: first confirm
   whether the user prefers host bind mounts or Docker named
   volumes.
