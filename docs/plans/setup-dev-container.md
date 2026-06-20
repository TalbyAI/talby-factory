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

| Category | Files | Responsibility |
|----------|-------|----------------|
| Image or base environment tooling | `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile` | Define the supported container baseline and install workspace-independent base tooling |
| Repo-local tooling | `package.json`, `Justfile`, `scripts/doctor.mjs` | Expose the bounded command surface and Layer 1 diagnostics |
| Runtime integrations | None in Layer 1 | Deferred to a later layer by design |
| `HOME` projections | None in Layer 1 | Deferred to a later layer by design |
| Manual or credential-dependent steps | Dev Container rebuild or reopen | Required to materialize image-time changes in the running environment |

## Supported Commands

Layer 1 exposes a deliberately narrow public surface:

```bash
pnpm doctor
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
pnpm doctor
just --list
```

Expected behavior:

* `pnpm doctor` reports only Layer 1 findings
* missing `just` in an already-running container is a rebuild signal, not a runtime integration failure
* `just --list` succeeds after the Dev Container is rebuilt or reopened from the repo-declared image path

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

## Deferred Work

The following concerns are intentionally deferred beyond Layer 1:

* runtime integrations and agent hosts
* `HOME` projection and user-scoped config writes
* authentication-dependent setup
* broader setup or repair workflows

For the retired mixed-responsibility bootstrap model and its replacement
mapping, see `.devcontainer/archive/legacy-bootstrap.md`.

- La documentación oficial de `markdownlint-cli2` confirmó que el paquete correcto es `markdownlint-cli2` y que el canal reproducible para este contenedor es `npm install -g markdownlint-cli2`.
- La versión fijada en el bootstrap quedó en `0.22.1` y se agregó al bloque npm global de `/.devcontainer/post-create.sh`.
- La verificación automática elegida para el bootstrap es `markdownlint-cli2 --help >/dev/null`; en validación interactiva el comando mostró `markdownlint-cli2 v0.22.1 (markdownlint v0.40.0)`.
- La decisión de este repo es no crear todavía configuración adicional como `.markdownlint*` o `.markdownlint-cli2.*`; por ahora solo se instala la CLI y se deja explícito que cualquier policy de reglas queda para una tarea posterior.
- La guía del contenedor quedó actualizada con comandos mínimos de uso y verificación: `markdownlint-cli2 "**/*.md"` y `markdownlint-cli2 --fix "**/*.md"`.
- La rerun completa del bootstrap terminó sin conflicto con otras herramientas Node globales ya presentes; `markdownlint-cli2` quedó accesible en `/usr/local/share/nvm/versions/node/v24.16.0/bin/markdownlint-cli2`.

**Task 9: `csharpier`**
- [x] Confirmar si `csharpier` debe instalarse como `.NET global tool` y cuál es su versión objetivo.
- [x] Añadir constante de versión y comando `dotnet tool update --global` o `install --global` en /.devcontainer/post-create.sh.
- [x] Verificar que el `PATH` actual ya cubre tools para el binario.
- [x] Añadir verificación del comando al final del script.
- [x] Definir si el repo necesita configuración adicional o si por ahora basta con el binario instalado.
- [x] Documentar el uso básico y la validación en la guía del contenedor.
- [x] Reejecutar bootstrap para comprobar que convive correctamente con `aspire.cli`.

Resultado validado de Task 8:

- La documentación oficial de CSharpier confirmó instalación como `.NET global tool`; la versión objetivo fijada para este bootstrap quedó en `1.3.0`.
- `/.devcontainer/post-create.sh` ahora usa el mismo patrón idempotente que `aspire.cli`: `dotnet tool update --global csharpier --version "$CSHARPIER_VERSION" || dotnet tool install --global csharpier --version "$CSHARPIER_VERSION"`.
- El chequeo barato del entorno confirmó que `PATH` ya incluye `~/.dotnet/tools`; la validación real mostró que el shim expuesto es `csharpier`, no `dotnet-csharpier`, en `/home/vscode/.dotnet/tools/csharpier`.
- La verificación final del bootstrap quedó como `command -v csharpier >/dev/null` y `csharpier --version`, que devolvió `1.3.0` en terminal limpia.
- La decisión del repo es no crear todavía tool manifest local ni configuración adicional; por ahora basta con el binario global instalado y documentado.
- La guía del contenedor quedó actualizada con uso mínimo real: `csharpier format .` y `csharpier check .`.
- La rerun completa del bootstrap confirmó convivencia correcta con `aspire.cli`; ambos global tools siguen resolviendo sin wiring extra.

**Task 10: `biome`**
- [x] Confirmar el paquete oficial exacto y la forma de instalación global recomendada para Linux.
- [x] Fijar versión e incorporarla al bloque npm global de /.devcontainer/post-create.sh si corresponde.
- [x] Añadir verificación del binario al final del script.
- [x] Definir si solo se instala la herramienta o también se deja pendiente configuración de repo.
- [x] Documentar cómo validar la instalación y qué no queda configurado todavía.
- [x] Verificar que no interfiere con otras herramientas Node del entorno.

Resultado validado de Task 9:

- La documentación oficial de Biome confirmó que el paquete npm correcto es `@biomejs/biome`; para este contenedor se adoptó instalación global reproducible con `npm install -g @biomejs/biome`.
- La versión fijada en el bootstrap quedó en `2.5.0` y se agregó al bloque npm global de `/.devcontainer/post-create.sh`.
- La verificación automática elegida para el bootstrap es `biome --version`, que devolvió `Version: 2.5.0` en la validación posterior.
- La decisión del repo es dejar pendiente cualquier `biome.json` o inicialización de proyecto; en esta tarea solo se instala la herramienta y se documenta explícitamente que la configuración del repo no quedó adoptada todavía.
- La guía del contenedor quedó actualizada con validación y uso mínimo real: `biome --version`, `biome check .` y `biome format .`.
- La rerun completa del bootstrap confirmó que `@biomejs/biome` no interfiere con las demás herramientas Node globales del entorno y que el binario queda accesible en `/usr/local/share/nvm/versions/node/v24.16.0/bin/biome`.

**Task 11: `opensrc` CLI + skill global**

- [x] Confirmar el paquete oficial exacto del CLI y su instalación global
	reproducible.
- [x] Fijar versión del CLI e incorporarla al bloque npm global de
	/.devcontainer/post-create.sh.
- [x] Añadir verificación del binario al final del script.
- [x] Confirmar si la skill oficial puede instalarse globalmente para Codex,
	GitHub Copilot y OpenCode sin escribir en el repo.
- [x] Definir si conviene pinnear la skill a un tag o ref explícita.
- [x] Incorporar la instalación de la skill al flujo existente de
	/.devcontainer/post-create-host-setup.sh.
- [x] Documentar qué queda automatizado y qué sigue siendo manual para no mutar
	el workspace.
- [x] Validar que el source pinneado de la skill se resuelve correctamente con
	`skills`.

Resultado validado de Task 11:

- La documentación oficial de `opensrc` confirmó instalación global
	reproducible con `npm install -g opensrc`; para este repo se fijó la versión
	`0.7.2`.
- `/.devcontainer/post-create.sh` ahora instala `opensrc@0.7.2` dentro del
	bloque npm global ya usado para el resto de CLIs Node y lo verifica con
	`opensrc --version`.
- La skill oficial existe dentro del mismo repo en `skills/opensrc/SKILL.md`,
	así que no hizo falta inventar instrucciones globales manuales ni copiar
	artifacts al workspace.
- La instalación global de la skill quedó integrada al host setup con
	`skills add vercel-labs/opensrc/skills/opensrc#v0.7.2 --global --yes --agent codex github-copilot opencode`.
- Se eligió pinnear la skill al tag `v0.7.2` para mantener alineados el
	binario `opensrc` y el contenido de la skill, aunque el requerimiento de pin
	no era crítico.
- La validación acotada del source de la skill se hizo con
	`skills add ... --list`, que resolvió correctamente
	`https://github.com/vercel-labs/opensrc.git @ v0.7.2 (skills/opensrc)` y
	listó una única skill llamada `opensrc`.
- La decisión final de este repo es no automatizar ninguna mutación de
	`AGENTS.md`, `.gitignore` ni otros archivos del workspace desde `opensrc`;
	el bootstrap solo deja instalado el CLI y la skill global, y cualquier uso
	que modifique archivos queda manual y explícito.

**Task 12: `ponytail` plugin**
- [ ] Confirmar el tag upstream exacto a pinnear para este repo.
- [ ] Definir la ruta canónica del checkout local, por ejemplo `~/.local/share/ponytail/<tag>`.
- [ ] Implementar la materialización del checkout pinneado desde `/.devcontainer/post-create-host-setup.sh` sin escribir artifacts generados en el workspace.
- [ ] Configurar Codex con `codex plugin marketplace add DietrichGebert/ponytail`.
- [ ] Configurar Codex con `codex plugin add ponytail@ponytail`.
- [ ] Verificar si la confianza de hooks de Codex se puede dejar presembrada o si debe quedar como paso manual documentado.
- [ ] Configurar GitHub Copilot CLI con `copilot plugin marketplace add DietrichGebert/ponytail`.
- [ ] Configurar GitHub Copilot CLI con `copilot plugin install ponytail@ponytail`.
- [ ] Configurar OpenCode apuntando el array `plugin` al checkout pinneado de Ponytail.
- [ ] Enlazar `.opencode/command/*` hacia `~/.config/opencode/command/` de forma idempotente.
- [ ] Evaluar si conviene copiar `/.github/copilot-instructions.md` hacia `~/.copilot/copilot-instructions.md` como fallback opcional, sin reemplazar automáticamente las reglas propias del repo.
- [ ] Documentar en `/.devcontainer/README.md` qué parte queda automatizada y qué parte, si alguna, queda manual.
- [ ] Validar rerun e idempotencia de `/.devcontainer/post-create-host-setup.sh`.
- [ ] Añadir comandos de verificación para Codex, GitHub Copilot CLI y OpenCode.

**Task 13: Documentación final del contenedor**
- [ ] Actualizar /.devcontainer/README.md con la lista final de herramientas incluidas.
- [ ] Añadir comandos de verificación para cada herramienta instalada.
- [ ] Añadir notas de autenticación para las herramientas que lo requieran.
- [ ] Explicar explícitamente qué quedó automatizado y qué quedó manual.
- [ ] Confirmar que las versiones documentadas coinciden con las fijadas en el bootstrap.
- [ ] Evaluar si README.md necesita una referencia breve al alcance ampliado de la guía.

**Checklist de cierre por herramienta**
- [ ] La herramienta se instala sin error en Linux dentro del Dev Container.
- [ ] La instalación es repetible o quedó documentado por qué una parte es manual.
- [ ] El comando de verificación pasa en terminal limpia.
- [ ] El cambio no rompe herramientas ya existentes del bootstrap.
- [ ] La documentación quedó alineada con el comportamiento real.
- [ ] Si hubo configuración persistente, quedó en una ubicación versionable y explícita.
- [ ] Si hubo auth o secretos, no se almacenaron en el repo.

**Orden recomendado de implementación**
1. `markdownlint-cli2`
2. `biome`
3. `csharpier`
4. `context-mode`
5. `gitnexus`
6. `gh`
7. `gentle-ai`
8. `engram`
9. `gga`
10. `mattpocock/skills`
11. `opensrc`
12. `ponytail`
13. documentación final

Si querés, el siguiente paso lógico es que convierta esta checklist en un archivo real dentro del repo, por ejemplo /.devcontainer/tooling-tasks.md, para que quede versionado y visible para cualquiera que trabaje en el contenedor.

### WishList de mejoras futuras y herramientas opcionales

- [ ] `HVE Core` plugin:
  - Instalar en los agentes de CLI y no solamente en VS Code como extensión.
  - Se sabe que en copilot es posible instalarlo, pero no queda claro para el resto de agentes.
- [ ] `Headroom` MCP:
  - Compress tool outputs, logs, files, and RAG chunks before they reach the LLM. 60-95% fewer tokens, same answers. Library, proxy, MCP server. 
  - url: https://github.com/chopratejas/headroom
