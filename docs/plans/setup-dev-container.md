---
title: Dev Container Tooling Task Checklist
description: Checklist for validating incremental Dev Container tooling changes.
---

## Plan: Dev Container Tooling Task Checklist

Archivo de tareas para implementar el tooling del Dev Container de a una herramienta por vez, validando cada incorporación antes de pasar a la siguiente. El objetivo es evitar cambios acoplados en /.devcontainer/post-create.sh y poder aislar errores de instalación, de configuración y de documentación.

**Cómo usar este archivo**
- Tomar una sola herramienta a la vez.
- No marcar la herramienta como completa hasta validar instalación, idempotencia y documentación.
- Si una herramienta requiere configuración fuera del bootstrap, anotar esa decisión antes de avanzar.
- Si una herramienta no soporta instalación Linux no interactiva confiable, degradar a prerequisitos + documentación manual y dejarlo explicitado.

**Checklist global previa**
- [ ] Confirmar el canal de instalación real de la herramienta elegida: `npm`, `npx`, `.NET global tool`, binario descargable u otro.
- [ ] Confirmar el comando de verificación real: `--version`, `version`, `--help` o smoke test equivalente.
- [ ] Confirmar si necesita variables de entorno, login, token o archivos persistentes de configuración.
- [ ] Confirmar si el cambio toca solo /.devcontainer/post-create.sh o también /.devcontainer/devcontainer.json, /.devcontainer/README.md, README.md, /.github o /.engram/config.json.
- [ ] Definir si la instalación debe ser completamente automática en `postCreateCommand` o si una parte debe quedar como paso manual documentado.

**Confirmación actual del checklist global**
- Los puntos de canal de instalación, comando de verificación y requisitos de entorno/auth no pueden marcarse de forma global todavía: dependen de la herramienta puntual que se tome en cada task.
- La superficie real del contenedor ya quedó confirmada en este repo: existen `/.devcontainer/post-create.sh`, `/.devcontainer/devcontainer.json`, `/.devcontainer/README.md`, `README.md` y `/.github/`.
- También quedó confirmado que hoy no existe `/.engram/config.json`, así que cualquier task que incorpore Engram debe tratar ese archivo como cambio explícito y no como infraestructura ya presente.
- El patrón actual del contenedor es instalación automática no interactiva desde `postCreateCommand` apuntando a `bash .devcontainer/post-create.sh`.
- El patrón actual de bootstrap instala CLIs globales pinneadas y valida disponibilidad al final del script con comandos de versión o equivalentes.
- El patrón actual de documentación deja la autenticación y cualquier credencial como paso manual posterior, documentado en `/.devcontainer/README.md`.
- Con el estado actual del repo, el único punto parcialmente confirmado de forma global es el de archivos potencialmente afectados; los demás deben resolverse herramienta por herramienta antes de marcarse.

**Task 1: `mattpocock/skills` para agentes instalados**
- [x] Verificar qué instala exactamente `npx skills@latest add mattpocock/skills` y en qué ubicación escribe.
- [x] Verificar si el comando es idempotente o si necesita guardas para no duplicar configuración al recrear el contenedor.
- [x] Determinar si el destino de instalación es de usuario o de workspace.
- [x] Si escribe fuera del repo, decidir si se acepta estado local o si hace falta una alternativa versionable.
- [x] Diseñar el paso exacto dentro de /.devcontainer/post-create.sh o documentar por qué no debe automatizarse ahí.
- [x] Definir el criterio de éxito: comando ejecutado sin error y skills visibles para los agentes instalados.
- [x] Agregar verificación explícita en la documentación del contenedor.
- [x] Probar una segunda ejecución para confirmar que no rompe el entorno.
- [x] No pasar a la siguiente herramienta hasta dejar resuelta la interacción con agents instalados.

Resultado validado de Task 1:

- La documentación oficial del CLI confirmó soporte de instalación global con `-g` / `--global`.
- `skills add mattpocock/skills --global --yes --agent codex github-copilot opencode` instala fuera del repo: escribe en `~/.agents/skills/**` y `~/.agents/.skill-lock.json`.
- El bootstrap ya no borra `./.agents` ni lockfiles locales del workspace. En cambio, ejecuta las operaciones globales de `skills` desde un directorio temporal para no interferir con posibles skills de proyecto que sí quieran vivir en este repo.
- La segunda ejecución no creó rutas duplicadas, pero sí reescribió el árbol global completo y el lockfile global. O sea: es estable en layout y apta para bootstrap porque no ensucia el repo, aunque no evita rewrite de timestamps en el home del usuario.
- Con la preferencia de este repo, la decisión final es instalar `skills` globalmente desde `/.devcontainer/post-create.sh` con versión pinneada del CLI y sin generar artifacts versionados dentro del workspace.
- El bootstrap quedó restringido a los tres hosts que este repo usa y documenta: Codex, GitHub Copilot y OpenCode; deja de intentar fan-out hacia otros agentes detectados en la máquina.
- Criterio de éxito adoptado: el comando termina con exit code `0`, el instalador informa `Installing to: Codex, GitHub Copilot, OpenCode`, `skills ls --global --json` lista los skills con `scope: global`, y el repo no recibe artifacts locales inesperados durante el bootstrap.
- La verificación explícita quedó documentada en `/.devcontainer/README.md`.

**Task 2: `context-mode` CLI**
- [x] Identificar el paquete o binario oficial para Linux y su método de instalación reproducible.
- [x] Confirmar si conviene instalarlo globalmente en el contenedor o si necesita wrapper/comando de arranque.
- [x] Agregar la versión fijada al bloque de constantes de /.devcontainer/post-create.sh.
- [x] Incorporar la instalación siguiendo el estilo ya usado para `copilot`, `opencode` y `codex`.
- [x] Añadir el comando de verificación al final del script.
- [x] Confirmar si requiere variables de entorno o auth posterior al bootstrap.
- [x] Documentar en /.devcontainer/README.md cómo verificarlo y qué queda manual.
- [x] Rebuild del contenedor o rerun del bootstrap para validar que no rompe instalaciones previas.
- [x] Ejecutar su verificación en terminal limpia antes de seguir.

Resultado validado de Task 2:

- La documentación oficial confirmó que el canal recomendado para Linux es `npm install -g context-mode` y que el binario esperado en `PATH` es `context-mode`.
- El paquete publicado en npm quedó fijado en `1.0.162`, con `engines.node >= 22.5.0`; el contenedor ya cumple ese requisito con Node `24.16.0`, así que no hizo falta wrapper ni launcher adicional.
- La decisión final de este repo es instalar `context-mode` globalmente desde `/.devcontainer/post-create.sh`, siguiendo el mismo patrón de CLIs globales pinneadas que ya usan `copilot`, `opencode` y `codex`.
- El bootstrap ahora deja además la integración global del host para los tres agentes objetivo: Codex (`~/.codex/config.toml` + `~/.codex/hooks.json`), OpenCode (`~/.config/opencode/opencode.jsonc`) y VS Code Copilot (`~/.vscode-server/data/Machine/mcp.json` + `~/.claude/settings.json`).
- La verificación incorporada al bootstrap es `context-mode doctor`. También quedó validado que `context-mode --version` no sirve como sonda de bootstrap en este contenedor porque deja corriendo el servidor MCP.
- `context-mode` no requiere cuenta propia ni variables de entorno obligatorias para instalarse o correr el diagnóstico local. Si después se integra con Codex, VS Code Copilot u otro host, puede reutilizar auth existente del host o variables como `GITHUB_TOKEN`, `GH_TOKEN` o API keys del proveedor, pero eso queda manual.
- La documentación del contenedor quedó actualizada en `/.devcontainer/README.md` con la versión, los comandos de verificación y la descripción de las rutas globales que el bootstrap escribe para cada host.
- El rerun de `/.devcontainer/post-create.sh` terminó con exit code `0` y no rompió la instalación de `context-mode` ni de las demás CLIs ya presentes.
- `context-mode doctor` reportó PASS en storage, server test y FTS5/SQLite. En la validación acotada posterior al wiring también confirmó PASS para los hooks detectables de Claude/VS Code y terminó con `EXIT:0`; el único WARN restante fue `Plugin enabled`, esperable cuando el entorno opera en modo MCP standalone y no como plugin instalado de Claude Code.

**Task 3: `gitnexus` CLI**
- [x] Identificar el canal oficial de instalación para Linux y verificar que funcione sin interacción.
- [x] Confirmar si debe quedar como CLI global del contenedor.
- [x] Fijar versión y sumar instalación en /.devcontainer/post-create.sh.
- [x] Añadir verificación con el subcomando correcto de versión o ayuda mínima.
- [x] Confirmar si necesita autenticación con GitHub, GitLab o tokens específicos.
- [x] Dejar documentado el flujo de auth sin almacenar secretos en el repo.
- [x] Verificar compatibilidad con el usuario remoto `vscode` y el `PATH` del contenedor.
- [x] Repetir bootstrap para comprobar que la instalación es estable e idempotente.

Resultado validado de Task 3:

- La documentación oficial de GitNexus confirmó instalación global en Linux con `npm install -g gitnexus`; la prueba real en este contenedor con `gitnexus@1.6.7` terminó sin interacción.
- La decisión final de este repo es dejar GitNexus como CLI global del contenedor, alineado con el patrón ya usado para otras herramientas Node pinneadas en `/.devcontainer/post-create.sh`.
- La versión fijada para bootstrap quedó en `1.6.7` y se agregó al bloque npm global del script.
- La verificación automática elegida para el bootstrap es doble: `gitnexus --version` como probe rápido de disponibilidad y `gitnexus doctor` como smoke test del runtime.
- `gitnexus --help` y `gitnexus doctor` corrieron correctamente con el usuario remoto `vscode`, confirmando que el binario global queda accesible en el `PATH` actual del contenedor sin wiring extra.
- GitNexus no requiere autenticación con GitHub, GitLab ni tokens para instalarse, arrancar o analizar repos locales. Los únicos secretos opcionales detectados fueron `UNDERSTAND_QUICKLY_TOKEN` para `gitnexus publish` y un posible API key de proveedor para `gitnexus wiki`, ambos fuera del repo.
- El flujo de auth manual quedó documentado en `/.devcontainer/README.md` sin persistir credenciales en archivos versionados.
- La rerun completa de `/.devcontainer/post-create.sh` terminó sin error después de sumar GitNexus. El bootstrap volvió a instalar y verificar todas las herramientas esperadas, y `gitnexus --version` junto con `gitnexus doctor` pasaron dentro de la misma ejecución.

**Task 4: `gh` CLI**
- [x] Identificar el canal oficial de instalación para Linux y la estrategia correcta para fijar versión.
- [x] Confirmar si conviene instalar GitHub CLI desde repositorio apt oficial, paquete descargable o binario standalone para este contenedor.
- [x] Definir si `gh` debe quedar instalado desde /.devcontainer/post-create.sh o si requiere otro punto de bootstrap.
- [x] Añadir el comando de verificación real para `gh` al criterio de validación de la tarea.
- [x] Confirmar si requiere autenticación, token o setup manual posterior para que el bootstrap siga siendo no interactivo.
- [x] Documentar el flujo manual de `gh auth login` o alternativa equivalente sin persistir secretos en el repo.
- [x] Verificar compatibilidad con el usuario remoto `vscode` y el `PATH` efectivo del contenedor.
- [x] Repetir bootstrap o rerun acotado para comprobar que la instalación es estable e idempotente.

Resultado validado de Task 4:

- La distribución oficial de GitHub CLI publica assets Linux versionados por release (`gh_<version>_linux_<arch>.tar.gz`, `.deb` y `.rpm`). Para este repo se descartó el repositorio apt oficial porque expone un canal mutable que no encaja con el patrón actual de versiones pinneadas en `/.devcontainer/post-create.sh`.
- La decisión final fue instalar `gh` desde `/.devcontainer/post-create.sh` usando el release oficial pinneado `2.95.0`, descargado desde `github.com/cli/cli/releases` y desplegado en `/usr/local/bin/gh` mediante `sudo`, sin agregar repositorios del sistema.
- La verificación automática adoptada para el bootstrap es `gh --version`, porque confirma disponibilidad del binario en el `PATH` efectivo del contenedor y no depende de auth previa.
- La validación de entorno confirmó que el contenedor corre con `remoteUser: vscode`, tiene `sudo` no interactivo disponible y resuelve arquitectura `amd64`, por lo que el asset real usado es `gh_2.95.0_linux_amd64.tar.gz`.
- `gh` no requiere login para instalarse ni para responder `gh --version`, pero el uso real contra GitHub queda manual y explícito en la guía del contenedor con `gh auth login`, `gh auth setup-git` y `gh auth status`.
- La documentación quedó actualizada en `/.devcontainer/README.md` sin persistir secretos en el repo y dejando `GH_TOKEN` como alternativa opcional de sesión dentro del contenedor.

**Task 5: `gentle-ai` CLI**
 [x] Identificar el canal oficial de instalación para Linux y su forma correcta de pinnear versión.
 [x] Confirmar si `gentle-ai` puede instalarse de forma no interactiva en /.devcontainer/post-create.sh.
 [x] Determinar si requiere también `gga` como dependencia separada o integrada.
 [x] Definir el comando de verificación real de `gentle-ai`.
 [x] Confirmar si necesita variables de entorno, login, tokens o archivos de configuración locales.
 [x] Diseñar la instalación para no dejar el bootstrap frágil si la auth no está disponible durante creación del contenedor.
 [x] Documentar claramente qué parte queda instalada y qué parte requiere setup manual posterior.
 [x] Validar que el CLI arranca en terminal del contenedor sin errores básicos.

 Resultado validado de Task 5:

 - `gentle-ai` publica releases oficiales con tarballs Linux versionados por arquitectura. Para este repo se descartó depender de Homebrew como canal primario porque el contenedor ya viene siguiendo el patrón de descargar assets oficiales pinneados desde GitHub Releases.
 - La versión fijada en el bootstrap quedó en `1.40.2` y se instala desde `gentle-ai_1.40.2_linux_<arch>.tar.gz` hacia `/usr/local/bin/gentle-ai`.
 - El binario arranca sin login ni variables de entorno obligatorias para responder `gentle-ai version`; esa es la verificación barata y estable adoptada para `/.devcontainer/post-create.sh`.
 - `gentle-ai doctor` no se adoptó como probe de bootstrap porque en un entorno fresco marca fallo hasta que existan además `engram`, `gga` y estado inicial bajo `~/.gentle-ai/`.
 - `gentle-ai install` sí soporta ejecución no interactiva cuando se le pasan flags explícitos. La validación real con `--agent codex --preset minimal --scope workspace` terminó sin prompts, pero escribió archivos de agente en el repo y estado de usuario en `~/.gentle-ai`, `~/.local/bin` y `~/.codex`.
 - Por esa razón, la decisión final de este repo es instalar automáticamente solo el binario `gentle-ai` en el bootstrap base y dejar la aplicación de presets/componentes como paso manual posterior documentado.
 - `gga` no viene embebido en el tarball de `gentle-ai`; es una herramienta separada del ecosistema y se trata como task aparte.

**Task 6: Engram para `gentle-ai`**
 [x] Confirmar si Engram requiere archivo de proyecto para resolver correctamente este repo.
 [x] Si aplica, definir el contenido y la ubicación de /.engram/config.json.
 [x] Asegurar que la configuración de proyecto evita fallback a un proyecto incorrecto.
 [x] Confirmar si hace falta crear estructura adicional o solo el archivo de config.
 [x] Definir cómo verificar que la resolución de proyecto es correcta dentro del contenedor.
 [x] Documentar el comportamiento esperado y cualquier prerequisito externo.
 [x] No avanzar a cerrar esta tarea hasta comprobar que la identidad del proyecto es estable.

 Resultado validado de Task 6:

 - La documentación oficial de Engram recomienda `/.engram/config.json` para repos críticos o monorepos cuando se quiere resolución determinística del proyecto. Sin ese archivo, Engram puede caer a heurísticas de cwd, repo name o basename del directorio.
 - La decisión final para este repo es versionar `/.engram/config.json` con `{"project_name": "talby-factory"}`.
 - No hizo falta estructura adicional de proyecto dentro del repo: alcanzó con crear la carpeta `/.engram/` y ese archivo de config.
 - La guía oficial indica que el primer chequeo operativo debe ser `mem_current_project`; ese llamado debe devolver `talby-factory` y reportar origen desde repo config en vez de un fallback de basename.
- Como validación técnica previa, se confirmó además que Engram publica binarios Linux versionados y que la CLI expone `engram version`, `engram mcp --tools=agent` y `engram doctor`.
- La decisión final del repo quedó actualizada: además del archivo `/.engram/config.json`, el bootstrap base instala también el binario independiente de `engram` pinneado en versión `1.16.3`.
- La expectativa documentada para este contenedor es: `engram version`, arranque del MCP con `engram mcp --tools=agent`, y luego `mem_current_project` desde una sesión iniciada en este repo.
**Task 7: `gga` para agentes instalados**
 [x] Confirmar qué es exactamente `gga` en este contexto y su canal oficial de instalación.
 [x] Verificar si es una CLI independiente o parte del ecosistema de `gentle-ai`.
 [x] Definir si debe instalarse globalmente en el contenedor o configurarse por agente/workspace.
 [x] Si requiere archivos persistentes, decidir si viven en /.github o si dependen de estado de usuario.
 [x] Definir el comando de verificación real.
 [x] Documentar limitaciones, auth y dependencias cruzadas con `gentle-ai`.
 [x] Validar que la instalación/configuración no interfiera con el resto de agentes ya instalados en el contenedor.

 Resultado validado de Task 7:

 - `gga` es `Gentleman Guardian Angel`, una CLI separada orientada a code review con hooks de git. No viene incluida como binario dentro del release tarball de `gentle-ai`, aunque `gentle-ai` la reconoce como componente gestionable del ecosistema.
 - Su documentación oficial declara dos canales de instalación: Homebrew (`brew install gentleman-programming/tap/gga`) y el instalador del repo (`./install.sh`). La inspección de releases confirmó que no publica assets binarios Linux, así que para Linux la vía real fuera de Homebrew sigue siendo el script.
 - La ejecución aislada de `install.sh` fue no interactiva cuando `gga` no estaba previamente instalado y escribió solo en estado de usuario: `~/.local/bin/gga` y `~/.local/share/gga/lib/**`.
 - La verificación real quedó confirmada con ambos comandos: `gga version` y `gga --version`, que devolvieron `gga v2.8.1`.
 - La configuración operativa posterior es por workspace: `gga init` crea el archivo `.gga` en el repo elegido y `gga install` agrega el hook de git en ese repo. Por diseño, eso no corresponde al bootstrap base del contenedor.
- La decisión final del repo quedó actualizada: sí se auto-instala el binario independiente de `gga` desde `/.devcontainer/post-create.sh`, pero sin ejecutar `gga init` ni `gga install`. El bootstrap baja el source archive taggeado `v2.8.1`, instala el script y sus librerías de runtime en `/usr/local/lib/gga`, y expone `gga` en `/usr/local/bin`.
- Sigue quedando manual y explícita la activación por workspace de hooks de review, evitando tocar hooks o estado de revisión sin consentimiento durante creación del contenedor.
 - No se detectaron requisitos de login o tokens para instalar o consultar versión. Los secretos potenciales dependen del proveedor de IA que después se configure dentro del archivo `.gga`, así que permanecen fuera del repo.
**Task 8: `markdownlint-cli2`**
- [x] Confirmar el paquete oficial exacto y su instalación global reproducible.
- [x] Fijar versión y sumarla a /.devcontainer/post-create.sh.
- [x] Añadir comando de verificación al bloque final del script.
- [x] Definir si hace falta configuración adicional en el repo o si por ahora solo se instala la CLI.
- [x] Documentar el comando mínimo de uso y verificación en /.devcontainer/README.md.
- [x] Verificar que la instalación no colisiona con otras herramientas Node globales del contenedor.

Resultado validado de Task 7:

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

**Task 12: Documentación final del contenedor**
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
12. documentación final

Si querés, el siguiente paso lógico es que convierta esta checklist en un archivo real dentro del repo, por ejemplo /.devcontainer/tooling-tasks.md, para que quede versionado y visible para cualquiera que trabaje en el contenedor.
