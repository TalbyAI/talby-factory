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
* GitNexus CLI `1.6.7`
* GitHub CLI `2.95.0`
* markdownlint-cli2 `0.22.1`
* CSharpier `1.3.0`
* Biome `2.5.0`
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
gitnexus --version
gitnexus doctor
gh --version
markdownlint-cli2 --help | head -n 2
csharpier --version
biome --version
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

GitNexus is installed globally with `npm install -g gitnexus@1.6.7`.
The bootstrap uses `gitnexus --version` as the fast availability probe and
`gitnexus doctor` as the runtime smoke test for the `vscode` user inside the
container.

GitHub CLI is installed from the official pinned release asset instead of the
mutable apt repository channel. The bootstrap downloads
`gh_2.95.0_linux_<arch>.tar.gz` from `github.com/cli/cli/releases`, extracts it
into `/usr/local/lib/gh-cli`, and installs the `gh` binary into
`/usr/local/bin/gh`.
`gh --version` is the bootstrap verification probe because it is auth-neutral
and confirms the binary is available on the effective container `PATH`.

Minimal usage and verification:

```bash
gh --version
gh auth status
gh repo view
```

`markdownlint-cli2` is installed globally with
`npm install -g markdownlint-cli2@0.22.1`.
The bootstrap uses `markdownlint-cli2 --help` as the availability probe.
No repository configuration is created for it yet, so the tool is installed and
ready, but rules and ignores still depend on future repo-level `.markdownlint*`
or `.markdownlint-cli2.*` configuration if the project adopts one.

Minimal usage and verification:

```bash
markdownlint-cli2 "**/*.md"
markdownlint-cli2 --fix "**/*.md"
```

`csharpier` is installed globally with
`dotnet tool update --global csharpier --version 1.3.0` and falls back to
`dotnet tool install --global` on first bootstrap.
The current container `PATH` already includes `~/.dotnet/tools`, so the exposed
global command is `csharpier`.
No local tool manifest or repository config is created yet.

Minimal usage and verification:

```bash
csharpier format .
csharpier check .
```

`biome` is installed globally with `npm install -g @biomejs/biome@2.5.0`.
The bootstrap uses `biome --version` as the fast availability probe.
No `biome.json` or other repository configuration is created yet, so the CLI is
available without committing the repo to Biome rules until a later task decides
that explicitly.

Minimal usage and verification:

```bash
biome check .
biome format .
```

## Authentication Notes

Some CLIs may require authentication after the container starts.
Use the normal sign-in flow for each tool inside the container when you
first need it.

`context-mode` itself does not require a separate account to install or run its
local diagnostics. If you later wire it into an agent host, that integration may
reuse the host's existing auth or environment variables such as `GITHUB_TOKEN`,
`GH_TOKEN`, or provider API keys. That setup stays manual and is not part of the
bootstrap.

GitNexus does not require GitHub, GitLab, or token-based authentication to
install, run `gitnexus doctor`, or index local repositories with `gitnexus
analyze`. Optional authenticated flows remain manual: `gitnexus publish` needs
`UNDERSTAND_QUICKLY_TOKEN`, and LLM-backed `gitnexus wiki` setup may persist a
provider API key under `~/.gitnexus/config.json` the first time you enable it.
Those secrets stay outside the repository.

GitHub CLI also stays non-interactive during bootstrap. Installation and
`gh --version` do not require login, but any repository or API operation does.
The manual sign-in flow stays outside the repo:

```bash
gh auth login
gh auth setup-git
gh auth status
```

If you prefer token-based auth in a throwaway session, export `GH_TOKEN` inside
the container instead of storing credentials in repository files.

`markdownlint-cli2`, `csharpier`, and `biome` do not require login, tokens, or
environment variables for installation or for the local verification commands
documented above.

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
