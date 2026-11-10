---
name: tarea
description: Empezar, terminar o consultar una tarea del proyecto con su propia rama de git. Usar cuando Gabi o Lucho dicen "empiezo la L3", "arranco una tarea nueva", "terminé la G2", "cerrá la tarea", "subí la tarea a develop", "¿por cuál va Lucho?" o "¿cómo vamos?". Crea la rama desde develop, la sube, la mergea a develop resolviendo conflictos, borra la rama y deja todo anotado en docs/TAREAS.md y docs/REGISTRO.md.
---

# Tareas con rama propia

Cada tarea vive en `docs/TAREAS.md` (L… de Lucho, G… de Gabi) y se hace en su propia rama. Al terminarla se mergea a
`develop`, se borra la rama y queda anotada en `docs/REGISTRO.md`. Así cada uno ve en qué anda el otro.

Pedir esta skill ya es el permiso para commitear y pushear lo de la tarea. Nada más: si aparece otro trabajo sin
commitear que no es de la tarea, preguntar antes de incluirlo.

## Quién soy

`git config user.name`: `Gabi` → Gabi (prefijo `gabi/`, tareas G). Cualquier otro nombre: preguntar una vez si es
Lucho y, si lo es, usar prefijo `lucho/` y tareas L. Nunca tocar el estado de una tarea del otro, salvo que lo pida.

## Estados en TAREAS.md

| Estado | Cómo se escribe la línea |
|---|---|
| Pendiente | `- [ ] **L3. Ventana K, lista.** …` |
| En curso | `- [ ] 🔄 **L3. Ventana K, lista.** … — *en curso: Lucho, rama `lucho/l3-ventana-lista`, desde 2026-11-10*` |
| Verificada | `- [x] ✅ **L3. Ventana K, lista.** … — *verificada 2026-11-12, rama `lucho/l3-ventana-lista` (borrada), merge `abc1234`*` |

Arriba de todo, la tabla **En curso** dice qué tiene abierto cada uno: se actualiza al empezar y al terminar.

## Empezar una tarea

1. `git status`: si hay cambios sin commitear, preguntar qué hacer con ellos (guardarlos con `git stash`, incluirlos
   en la tarea o dejarlos). No arrancar con cambios ajenos mezclados.
2. Actualizar develop: `git checkout develop`, `git pull --ff-only origin develop`.
3. Ubicar la tarea en `docs/TAREAS.md`. Si es nueva, agregarla en la sección que corresponda con el número
   siguiente (L… o G…), en una línea con qué es y cuándo está lista.
4. Rama: `<prefijo>/<id en minúscula>-<dos o tres palabras>`, por ejemplo `gabi/g2-foso-ceniza`.
   `git checkout -b <rama>`.
5. Marcarla 🔄 con quién, rama y fecha, y ponerla en la tabla **En curso**. Commit
   `Empieza <ID>: <nombre>` y `git push -u origin <rama>`. Así el otro la ve en curso aunque no haya código todavía.
6. Decir en una línea: la rama, y que al terminar se pida "terminé la <ID>".

## Mientras se trabaja

- Commits chicos en la rama, con mensajes en castellano que digan qué cambió.
- `git push` de la rama cuando se pida subir o al cerrar el día, para que quede en remoto.
- Si la tarea toca `player.gd`, `model_rig.gd`, `humanoid_rig.gd`, `npc.gd` o `metal_bar.gd`: cambios puntuales
  (ver `CLAUDE.md`).

## Terminar una tarea

1. **Probar.** Correr lo que la tarea dice en "listo cuando" y las pruebas que toque (`tools/anim_check/`). Después de
   abrir Godot, `git checkout -- project.godot`. Si es animación, no se cierra hasta que el usuario la haya jugado
   (`CLAUDE.md`): preguntar.
2. **Commit final en la rama.** Nunca agregar `textures.rar`, los `.import` de Effekseer
   (`assets/effects/effekseer/Textures/*.png.import`) ni los `~*.dll` de `addons/`. Revisar `git status` antes:
   nada de `__pycache__`, `.godot/` ni videos.
3. `git push origin <rama>`.
4. `git checkout develop` y `git pull --ff-only origin develop`.
5. `git merge --no-ff <rama>` con el mensaje `Merge <rama>: <ID> <nombre>`.
6. **Conflictos:** resolverlos entendiendo los dos lados; si un lado es del compañero y no está claro cuál va,
   preguntar. Después, correr el juego sin ventana para ver que no haya errores de script:
   `timeout 180 <godot> --headless --path . --quit-after 300 > log 2>&1` y buscar `ERROR`/`Parse Error`; luego
   `git checkout -- project.godot`.
7. **Anotar** (en develop, antes de pushear):
   - `docs/TAREAS.md`: la tarea pasa a `- [x] ✅` con fecha, rama (borrada) y el hash corto del merge; sacarla de
     **En curso**.
   - `docs/REGISTRO.md`: una entrada nueva arriba de todo (formato abajo).
   - Si la tarea venía de `docs/PERSONAJES.md` (P…, Y…), tacharla también ahí.
   - Commit `Registro: <ID> verificada` en develop.
8. `git push origin develop`.
9. Borrar la rama: `git branch -d <rama>` y `git push origin --delete <rama>`. Solo después de que el push de develop
   salió bien; si algo falló, la rama se queda.
10. Contar en dos líneas: qué se mergeó, si hubo conflictos y cómo se resolvieron, y qué tarea sigue para esa persona.

Si el merge sale mal y no se quiere seguir: `git merge --abort` y avisar. Nunca `push --force` a develop.

## Formato de REGISTRO.md

```markdown
### 2026-11-12 · L3 · Ventana K, lista · Lucho
- **Rama:** `lucho/l3-ventana-lista` (borrada) · **Merge:** `abc1234`
- **Qué se hizo:** botones + y − por poder, indicador 0/5, motivo cuando no se puede subir.
- **Archivos:** `scripts/ui/skill_tree_window.gd`, `scripts/progression/progression.gd`
- **Cómo se probó:** progression_check pasa; subir y bajar desde K.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** pedido de animación para Furia (ver TAREAS.md).
```

## "¿Por cuál va?" / "¿Cómo vamos?"

`git fetch origin`, leer la tabla **En curso** de `docs/TAREAS.md` en `origin/develop` y las ramas remotas
(`git branch -r`). Contar, por persona: tarea en curso con su rama y fecha, la última verificada y cuántas faltan.
Si hay una rama remota que no figura en curso, mencionarla.
