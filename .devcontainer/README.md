---
title: DevContainer Guide
description: Setup and usage notes for the talby-factory development container.
---

## Overview

This folder contains the DevContainer definition for this repository.
The container keeps the official .NET image as the base and layers the
project-specific tooling on top through Dev Container features and a
post-create bootstrap script.

## Included Tooling

* .NET SDK from `mcr.microsoft.com/devcontainers/dotnet:2-10.0-noble`
* Docker access from the host via the Docker outside-of-Docker feature
* Node.js `24.16.0`
* pnpm `11.7.0`
* Aspire CLI `13.4.5`
* GitHub Copilot CLI `1.0.63`
* OpenCode CLI `1.17.7`
* Codex CLI `0.140.0`
* Context Mode CLI `1.0.162`
* Skills CLI `1.5.11`

## Global Context Mode Host Wiring

The Dev Container also bootstraps global `context-mode` host integration for the
three agent hosts already installed in the container:

* Codex CLI via `~/.codex/config.toml` and `~/.codex/hooks.json`
* OpenCode via `~/.config/opencode/opencode.jsonc`
* VS Code Copilot via remote-user MCP config at
   `~/.vscode-server/data/Machine/mcp.json` and global hook config at
   `~/.claude/settings.json`

This keeps the hook and MCP wiring out of the repository and makes the setup
repeatable on container rebuild.

## Global Agent Skills

The Dev Container bootstraps `mattpocock/skills` globally for the `vscode`
user instead of writing generated skill artifacts into the repository.

The bootstrap installs the pinned `skills` CLI and then runs:

```bash
skills add mattpocock/skills --global --yes --agent codex github-copilot opencode
```

The bootstrap intentionally limits `skills` fan-out to the three agent hosts this
repo already configures: Codex, GitHub Copilot, and OpenCode.

All global `skills` operations that the bootstrap performs are executed from a
temporary directory so the CLI can write any transient working files there
instead of mutating repository-local skill state such as `./.agents` or local
lockfiles.

This writes the installed skills to `~/.agents/skills/` and the global
lockfile to `~/.agents/.skill-lock.json`.

The command was validated to detect the installed agents non-interactively
and install the skills for Codex, GitHub Copilot, and OpenCode.

## Files

* [devcontainer.json](./devcontainer.json) defines the container image,
  features, VS Code customizations, and lifecycle commands.
* [post-create.sh](./post-create.sh) installs the pinned CLI tools and
  verifies that they are available after the container is created.

## How To Use It

1. Open the repository in Visual Studio Code.
2. Run the Dev Containers command to reopen the workspace in the
   container.
3. Wait for the container build and the `postCreateCommand` bootstrap to
   finish.
4. Open a new terminal in the container and verify the tools if needed.

```bash
docker --version
node --version
pnpm --version
aspire --version
copilot --version
opencode --version
codex --version
context-mode doctor
skills --version
```

`context-mode doctor` is the bootstrap smoke test because the official docs use
it to validate runtimes and SQLite/FTS5 support from the installed CLI. In this
container, `context-mode --version` starts the MCP server process instead of
acting as a one-shot version probe, so the bootstrap intentionally avoids it.
After the bootstrap writes the global host configuration, Codex-specific hook
warnings should be limited to trust or runtime conditions rather than missing
files.

To inspect the generated global host config:

```bash
cat ~/.codex/config.toml
cat ~/.codex/hooks.json
cat ~/.config/opencode/opencode.jsonc
cat ~/.vscode-server/data/Machine/mcp.json
cat ~/.claude/settings.json
```

To verify the globally installed agent skills:

```bash
test -f ~/.agents/.skill-lock.json
find ~/.agents/skills -maxdepth 2 -name SKILL.md | head
skills ls --global --json
```

The install is considered successful when the command exits without error,
prints `Installing to: Codex, GitHub Copilot, OpenCode`, and `skills ls
--global --json` reports the installed skills with `scope: global`.

## Authentication Notes

Some CLIs may require authentication after the container starts.
Use the normal sign-in flow for each tool inside the container when you
first need it.

`context-mode` itself does not require a separate account to install or run its
local diagnostics. If you later wire it into an agent host, that integration may
reuse the host's existing auth or environment variables such as `GITHUB_TOKEN`,
`GH_TOKEN`, or provider API keys. That setup stays manual and is not part of the
bootstrap.

OpenCode does not need a separate stdio MCP block because `context-mode` runs as
an OpenCode plugin. VS Code Copilot still requires normal MCP server trust inside
the editor the first time the global user-profile server is discovered.

The global `~/.claude/settings.json` hook file is written specifically for the
VS Code Copilot adapter commands. If you later use Claude Code in the same
container, review that file before reusing it there.

> [!IMPORTANT]
> The bootstrap script installs the CLIs, but it does not persist your
> credentials for you. Sign in from inside the container when required.

## Updating Versions

When you need to change pinned versions, update both of these files:

* [devcontainer.json](./devcontainer.json)
* [post-create.sh](./post-create.sh)

Keep the versions aligned so the JSON configuration and the bootstrap
behavior stay consistent.
