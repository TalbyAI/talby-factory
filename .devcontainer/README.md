---
title: DevContainer Guide
description: Setup and usage notes for the talby-factory development container.
---

## Overview

This folder contains the DevContainer definition for this repository.
The container keeps the official .NET image as the base and layers the
project-specific tooling on top through Dev Container features, a
base post-create bootstrap script, host Git config inheritance, and a separate
optional host setup script.

## Host Git Identity and SSH Signing

The Dev Container now mounts the host `~/.gitconfig` read-only at
`/home/vscode/.gitconfig-host`. During bootstrap, the container evaluates that
config with its host-side includes, extracts only the compatible identity and
signing settings into a sanitized include file, and registers that sanitized
file as a global Git include for the `vscode` user.

This gives the container access to shared Git identity and signing settings
from the host without copying secrets into the repository and without importing
host-only settings such as Windows `safe.directory` entries or `gpg.program`
paths that do not exist on Linux.

If the evaluated host config still uses OpenPGP signing, the bootstrap now
falls back to SSH signing automatically when the forwarded SSH agent exposes at
least one public key. It prefers an `ssh-ed25519` key and otherwise uses the
first available key from the agent.

The current setup is intended for:

* inheriting `user.name` and `user.email` from the host
* inheriting SSH commit-signing settings from the host
* continuing to use the SSH agent that VS Code already forwards into the
  container

The recommended signing strategy for this repository is SSH signing instead of
OpenPGP/GPG signing. SSH signing reuses the forwarded host SSH agent and avoids
having to move private GPG key material or agent sockets into the container.

### Recommended Host Git Configuration

Add the following to the host Git config that you want the container to inherit:

```ini
[user]
   name = Your Name
   email = you@example.com
   signingKey = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... you@example.com

[gpg]
   format = ssh

[commit]
   gpgsign = true

[tag]
   gpgSign = true
```

If you prefer not to store the SSH public key inline in `user.signingKey`, Git
also supports pointing `user.signingKey` at a public key file on the host.

### Optional Signature Verification Settings

If you also want local signature verification inside the container, add an
allowed signers file on the host and reference it from your inherited config:

```ini
[gpg "ssh"]
   allowedSignersFile = ~/.config/git/allowed_signers
```

The signing step itself does not require `allowedSignersFile`; it is only
needed for local verification workflows such as `git log --show-signature`.

### Notes About Host Config Scope

The bootstrap always imports `user.name` and `user.email` from the evaluated
host config when those values exist.

SSH signing settings are imported only when the evaluated host config is
already SSH-based and portable inside the container, specifically when:

* `gpg.format = ssh`
* `user.signingKey` is present

When the host is configured for OpenPGP signing or uses a platform-specific
`gpg.program`, the bootstrap intentionally skips signing settings rather than
carrying a broken configuration into Linux.

When an SSH key is available from the forwarded agent, that OpenPGP case is
upgraded automatically to container-local SSH signing instead of being left
unsigned.

Other host-specific sections, helpers, includes, and `safe.directory` entries
are intentionally ignored so the container does not inherit machine-specific
paths that are invalid on Linux.

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
* Gentle AI CLI `1.40.2`
* Engram CLI `1.16.3`
* GGA CLI `2.8.1`
* markdownlint-cli2 `0.22.1`
* CSharpier `1.3.0`
* Biome `2.5.0`
* Skills CLI `1.5.11`

## Optional Host-Level Agent Setup

The Dev Container now separates base container bootstrap from optional
user-level agent host personalization:

* `postCreateCommand` runs `bash .devcontainer/post-create.sh`
* optional host setup runs manually with
   `bash .devcontainer/post-create-host-setup.sh`

The base bootstrap installs the pinned CLIs and verifies they are available in
the container. The optional script applies global `skills` installation and
Context Mode host wiring for the current `vscode` user.

Run the optional script only when you want this container instance to also own
global agent personalization state under the user home directory.

## Global Context Mode Host Wiring

The optional host setup script bootstraps global `context-mode` host integration
for the three agent hosts already installed in the container:

* Codex CLI via `~/.codex/config.toml` and `~/.codex/hooks.json`
* OpenCode via `~/.config/opencode/opencode.jsonc`
* VS Code Copilot via remote-user MCP config at
   `~/.vscode-server/data/Machine/mcp.json` and global hook config at
   `~/.claude/settings.json`

This keeps the hook and MCP wiring out of the repository and makes the setup
repeatable on container rebuild.

The optional setup now shares JSON merge helpers from
`./config-helpers.js`, which keeps the repeated read-merge-write logic for
hook and MCP files consistent across Codex, OpenCode, and VS Code Copilot.

## Global Agent Skills

The optional host setup script bootstraps `mattpocock/skills` globally for the
`vscode` user instead of writing generated skill artifacts into the repository.

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

## Gentle AI, Engram, and GGA

The base bootstrap now installs the pinned standalone binaries for
`gentle-ai`, `engram`, and `gga`.
That keeps the container-level bootstrap reproducible while still avoiding the
more invasive ecosystem application steps that write agent configs, project
hooks, or provider-specific runtime state.

`gentle-ai` was validated on Linux as a versioned upstream tarball release.
The current bootstrap pins `1.40.2` and installs the standalone binary into
`/usr/local/bin`.

`engram` was validated on Linux as a versioned upstream tarball release.
The current bootstrap pins `1.16.3` and installs the standalone binary into
`/usr/local/bin`.

`gga` does not publish release binaries for Linux. The current bootstrap pins
`2.8.1`, downloads the tagged source archive, installs the CLI script and its
runtime helper libraries under `/usr/local/lib/gga`, patches the pinned version
and runtime library path exactly as the upstream installer does, and exposes the
command at `/usr/local/bin/gga`.

The verification command for the base bootstrap is:

```bash
gentle-ai version
engram version
gga version
```

`gentle-ai doctor` is intentionally not part of the base bootstrap validation.
It fails on a fresh environment until companion tools such as `engram` and
`gga` exist on `PATH` and until initial Gentle AI state has been created.

The actual ecosystem application remains manual for now. `gentle-ai install`
can run non-interactively when all flags are provided, but even the minimal
preset writes agent files into the current repository and user-home state under
`~/.gentle-ai`, `~/.local/bin`, and agent-specific config directories.
That behavior is appropriate for an explicit setup step, not for the generic
container bootstrap.

`gga` is still treated as an independent CLI. Installing the binary in the
container does not initialize any repository or install any git hook. Those
steps remain explicit and manual with `gga init` and `gga install` in the repo
that should actually use commit-time review.

When you want to activate the full Gentle AI stack manually inside this
container, use this sequence in a fresh terminal:

```bash
gentle-ai version
gentle-ai install --agent codex --preset minimal --scope workspace
```

If you want to activate GGA inside this repo after the binary is present:

```bash
gga version
gga init
gga install
```

Engram project identity for this repository is pinned through the checked-in
`/.engram/config.json` file:

```json
{
   "project_name": "talby-factory"
}
```

This file is enough for repository-scoped default project resolution. No extra
repository structure is required beyond the `.engram/` directory that contains
that config file.

The expected verification flow for Engram inside the container is:

```bash
engram version
engram mcp --tools=agent
```

Then, from an agent session started in this repo, call `mem_current_project`.
The expected project is `talby-factory`, sourced from repo config rather than a
directory-basename fallback.

## Files

* [devcontainer.json](./devcontainer.json) defines the container image,
  features, host Git config mount, VS Code customizations, and lifecycle
  commands.
* [post-create.sh](./post-create.sh) installs the pinned CLI tools and
   verifies that they are available after the container is created and
   registers the mounted host Git config as a global include when present.
* [post-create-host-setup.sh](./post-create-host-setup.sh) applies optional
   global skills installation and Context Mode host wiring for the current user.
* [lib.sh](./lib.sh) contains small shared shell helpers reused by both
   bootstrap scripts.
* [config-helpers.js](./config-helpers.js) contains shared JSON merge helpers
   for the optional host setup script.

## How To Use It

1. Open the repository in Visual Studio Code.
2. Run the Dev Containers command to reopen the workspace in the
   container.
3. Wait for the container build and the base `postCreateCommand` bootstrap to
   finish.
4. Verify that host Git identity is visible inside the container:

```bash
git config --show-origin --get user.name
git config --show-origin --get user.email
git config --show-origin --get gpg.format
git config --show-origin --get user.signingkey
```

5. If you need global agent personalization in this container instance, run:

```bash
bash .devcontainer/post-create-host-setup.sh
```

6. Open a new terminal in the container and verify the tools if needed.

## Verification Checklist

Use the checks below according to the script you are validating. The two flows
have different goals and should be debugged separately.

### Base Bootstrap Checks

These checks map to `bash .devcontainer/post-create.sh`. They confirm that the
container-level CLI installation succeeded and that the pinned tools are
available on the container `PATH`.

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
gentle-ai version
engram version
gga version
markdownlint-cli2 --version
csharpier --version
biome --version
skills --version
git config --show-origin --get user.name
git config --show-origin --get user.email
git config --show-origin --get gpg.format
git config --show-origin --get user.signingkey
```

`context-mode doctor` appears in the base bootstrap because it is the current
runtime smoke test for the installed CLI itself: runtimes, server startup, and
SQLite/FTS5 support.

If host Git identity is configured correctly, the `git config --show-origin`
commands above should resolve from `/home/vscode/.gitconfig` or from the
sanitized include path under `~/.config/git/host-identity.inc`.

### Optional Host Setup Checks

Run these only after `bash .devcontainer/post-create-host-setup.sh`. They do
not validate container-wide installation; they validate user-level agent state
written under the `vscode` home directory.

To verify the optional host-level setup after running it:

```bash
context-mode doctor
test -f ~/.agents/.skill-lock.json
test -f ~/.codex/config.toml
test -f ~/.codex/hooks.json
test -f ~/.config/opencode/opencode.jsonc
test -f ~/.vscode-server/data/Machine/mcp.json
test -f ~/.claude/settings.json
skills ls --global --json
```

Here `context-mode doctor` serves a different purpose than in the base
bootstrap: it confirms that the global host wiring now exists and that any
remaining warnings are about trust or host runtime conditions rather than
missing config files.

`context-mode doctor` is the bootstrap smoke test because the official docs use
it to validate runtimes and SQLite/FTS5 support from the installed CLI. In this
container, `context-mode --version` starts the MCP server process instead of
acting as a one-shot version probe, so the bootstrap intentionally avoids it.
After the optional host setup writes the global host configuration,
Codex-specific hook warnings should be limited to trust or runtime conditions
rather than missing files.

To inspect the generated global host config after the optional script runs:

```bash
cat ~/.codex/config.toml
cat ~/.codex/hooks.json
cat ~/.config/opencode/opencode.jsonc
cat ~/.vscode-server/data/Machine/mcp.json
cat ~/.claude/settings.json
```

To verify the globally installed agent skills after the optional script runs:

```bash
test -f ~/.agents/.skill-lock.json
find ~/.agents/skills -maxdepth 2 -name SKILL.md | head
skills ls --global --json
```

The optional host setup is considered successful when the command exits
without error, prints `Installing to: Codex, GitHub Copilot, OpenCode`,
and `skills ls
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
The bootstrap uses `markdownlint-cli2 --version` as the availability probe.
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
base bootstrap.

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
> The base bootstrap script installs the CLIs, but it does not persist your
> credentials for you. The optional host setup script writes user-level agent
> config only when you run it explicitly. Sign in from inside the container when
> required.

## Updating Versions

When you need to change pinned versions, update both of these files:

* [devcontainer.json](./devcontainer.json)
* [post-create.sh](./post-create.sh)

Keep the versions aligned so the JSON configuration and the bootstrap
behavior stay consistent.
