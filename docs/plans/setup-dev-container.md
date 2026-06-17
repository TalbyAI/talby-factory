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
- `skills add mattpocock/skills --global --yes` instala fuera del repo: escribe en `~/.agents/skills/**` y `~/.agents/.skill-lock.json`.
- La segunda ejecución no creó rutas duplicadas, pero sí reescribió el árbol global completo y el lockfile global. O sea: es estable en layout y apta para bootstrap porque no ensucia el repo, aunque no evita rewrite de timestamps en el home del usuario.
- Con la preferencia de este repo, la decisión final es instalar `skills` globalmente desde `/.devcontainer/post-create.sh` con versión pinneada del CLI y sin generar artifacts versionados dentro del workspace.
- Criterio de éxito adoptado: el comando termina con exit code `0`, el instalador informa `Installing to: Codex, GitHub Copilot, OpenCode`, y `skills ls --global --json` lista los skills con `scope: global`.
- La verificación explícita quedó documentada en `/.devcontainer/README.md`.

**Task 2: `context-mode` CLI**
- [ ] Identificar el paquete o binario oficial para Linux y su método de instalación reproducible.
- [ ] Confirmar si conviene instalarlo globalmente en el contenedor o si necesita wrapper/comando de arranque.
- [ ] Agregar la versión fijada al bloque de constantes de /.devcontainer/post-create.sh.
- [ ] Incorporar la instalación siguiendo el estilo ya usado para `copilot`, `opencode` y `codex`.
- [ ] Añadir el comando de verificación al final del script.
- [ ] Confirmar si requiere variables de entorno o auth posterior al bootstrap.
- [ ] Documentar en /.devcontainer/README.md cómo verificarlo y qué queda manual.
- [ ] Rebuild del contenedor o rerun del bootstrap para validar que no rompe instalaciones previas.
- [ ] Ejecutar su verificación en terminal limpia antes de seguir.

**Task 3: `gitnexus` CLI**
- [ ] Identificar el canal oficial de instalación para Linux y verificar que funcione sin interacción.
- [ ] Confirmar si debe quedar como CLI global del contenedor.
- [ ] Fijar versión y sumar instalación en /.devcontainer/post-create.sh.
- [ ] Añadir verificación con el subcomando correcto de versión o ayuda mínima.
- [ ] Confirmar si necesita autenticación con GitHub, GitLab o tokens específicos.
- [ ] Dejar documentado el flujo de auth sin almacenar secretos en el repo.
- [ ] Verificar compatibilidad con el usuario remoto `vscode` y el `PATH` del contenedor.
- [ ] Repetir bootstrap para comprobar que la instalación es estable e idempotente.

**Task 4: `gentle-ai` CLI**
- [ ] Identificar el canal oficial de instalación para Linux y su forma correcta de pinnear versión.
- [ ] Confirmar si `gentle-ai` puede instalarse de forma no interactiva en /.devcontainer/post-create.sh.
- [ ] Determinar si requiere también `gga` como dependencia separada o integrada.
- [ ] Definir el comando de verificación real de `gentle-ai`.
- [ ] Confirmar si necesita variables de entorno, login, tokens o archivos de configuración locales.
- [ ] Diseñar la instalación para no dejar el bootstrap frágil si la auth no está disponible durante creación del contenedor.
- [ ] Documentar claramente qué parte queda instalada y qué parte requiere setup manual posterior.
- [ ] Validar que el CLI arranca en terminal del contenedor sin errores básicos.

**Task 5: Engram para `gentle-ai`**
- [ ] Confirmar si Engram requiere archivo de proyecto para resolver correctamente este repo.
- [ ] Si aplica, definir el contenido y la ubicación de /.engram/config.json.
- [ ] Asegurar que la configuración de proyecto evita fallback a un proyecto incorrecto.
- [ ] Confirmar si hace falta crear estructura adicional o solo el archivo de config.
- [ ] Definir cómo verificar que la resolución de proyecto es correcta dentro del contenedor.
- [ ] Documentar el comportamiento esperado y cualquier prerequisito externo.
- [ ] No avanzar a cerrar esta tarea hasta comprobar que la identidad del proyecto es estable.

**Task 6: `gga` para agentes instalados**
- [ ] Confirmar qué es exactamente `gga` en este contexto y su canal oficial de instalación.
- [ ] Verificar si es una CLI independiente o parte del ecosistema de `gentle-ai`.
- [ ] Definir si debe instalarse globalmente en el contenedor o configurarse por agente/workspace.
- [ ] Si requiere archivos persistentes, decidir si viven en /.github o si dependen de estado de usuario.
- [ ] Definir el comando de verificación real.
- [ ] Documentar limitaciones, auth y dependencias cruzadas con `gentle-ai`.
- [ ] Validar que la instalación/configuración no interfiera con el resto de agentes ya instalados en el contenedor.

**Task 7: `markdownlint-cli2`**
- [ ] Confirmar el paquete oficial exacto y su instalación global reproducible.
- [ ] Fijar versión y sumarla a /.devcontainer/post-create.sh.
- [ ] Añadir comando de verificación al bloque final del script.
- [ ] Definir si hace falta configuración adicional en el repo o si por ahora solo se instala la CLI.
- [ ] Documentar el comando mínimo de uso y verificación en /.devcontainer/README.md.
- [ ] Verificar que la instalación no colisiona con otras herramientas Node globales del contenedor.

**Task 8: `csharpier`**
- [ ] Confirmar si `csharpier` debe instalarse como `.NET global tool` y cuál es su versión objetivo.
- [ ] Añadir constante de versión y comando `dotnet tool update --global` o `install --global` en /.devcontainer/post-create.sh.
- [ ] Verificar que el `PATH` actual ya cubre tools para el binario.
- [ ] Añadir verificación del comando al final del script.
- [ ] Definir si el repo necesita configuración adicional o si por ahora basta con el binario instalado.
- [ ] Documentar el uso básico y la validación en la guía del contenedor.
- [ ] Reejecutar bootstrap para comprobar que convive correctamente con `aspire.cli`.

**Task 9: `biome`**
- [ ] Confirmar el paquete oficial exacto y la forma de instalación global recomendada para Linux.
- [ ] Fijar versión e incorporarla al bloque npm global de /.devcontainer/post-create.sh si corresponde.
- [ ] Añadir verificación del binario al final del script.
- [ ] Definir si solo se instala la herramienta o también se deja pendiente configuración de repo.
- [ ] Documentar cómo validar la instalación y qué no queda configurado todavía.
- [ ] Verificar que no interfiere con otras herramientas Node del entorno.

**Task 10: Documentación final del contenedor**
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
6. `gentle-ai`
7. `engram`
8. `gga`
9. `mattpocock/skills`
10. documentación final

Si querés, el siguiente paso lógico es que convierta esta checklist en un archivo real dentro del repo, por ejemplo /.devcontainer/tooling-tasks.md, para que quede versionado y visible para cualquiera que trabaje en el contenedor.
