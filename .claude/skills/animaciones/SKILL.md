---
name: animaciones
description: Cambiar, agregar o arreglar animaciones de personajes (Vin y los héroes, el Lord Legislador, koloss y demás) con clips reales de Meshy, Mixamo o ActionForge. Usar cuando el usuario pide una animación nueva o distinta para un poder, golpe, postura o movimiento, quiere bajar algo de Mixamo, retocar en ActionForge, o arreglar algo que "se ve raro", tironea, patina o flota.
---

# Animaciones de personajes

Reglas fijas: solo clips reales (Meshy, Mixamo, ActionForge, capturas), retocados con tramo, velocidad, Adjust de
ActionForge o capas de huesos en ActionForge. Nada generado por código. Bajar algo pide permiso, salvo que el usuario
ya lo haya pedido. Nunca escribir contraseñas: si Mixamo pide sesión, que el usuario entre.

## 1. Buscar el clip que hace el movimiento

1. Escribir el movimiento pedido en números: posición de la mano respecto del pecho, ángulo del codo (180 = estirado),
   hacia dónde apunta el brazo (0 = adelante, + = derecha del personaje), altura, inclinación del torso.
2. Buscar en orden:
   - Lo que ya hay: `docs/BIBLIOTECA_ANIMACIONES.md` (1000+ clips por archivo; `Vin.glb` tiene 190 de Meshy).
   - ActionForge: biblioteca de 85 clips (`sword_regular_a/b/c`, `melee_hook`, `ninjajump_start/land`, `spell_simple_*`,
     `punch_*`, `overhandthrow`...). Se pueden retocar con Adjust.
   - Mixamo (`https://www.mixamo.com/#/?page=1&query=<palabra>&type=Motion%2CMotionPack`) en el navegador integrado.
     Descargas: FBX Binary, **Without Skin** si se puede, 30 fps. `C:/Users/gabih/Downloads` tiene muchos ya bajados.
3. Comparar candidatos **con números, no a ojo** (las miniaturas engañan):
   ```
   G=/c/Users/gabih/Downloads/Godot/Godot_v4.7.2-stable_win64_console.exe
   $G --headless --path . -s tools/anim_check/arm_measure.gd -- "clip[@res://donante.glb]" 30
   ```

## 2. Armarlo en el .glb que corresponde

`tools/blender/anim_fbx_to_glb.py` junta FBX de solo animación (`"archivo.fbx=nombre"` renombra; los de Mixamo se
llaman todos `mixamo.com`). El primer FBX define el esqueleto de reposo de todo el archivo:
**no mezclar fuentes con distinta pose de reposo** o los brazos salen corridos.

| Fuente | Archivo |
|---|---|
| ActionForge | `assets/actionforge/AFClips.glb` |
| Mixamo bajado sobre un personaje propio | `assets/mixamo/HeroMixamo.glb` |
| Mixamo bajado sobre el X Bot (personaje por defecto) | `assets/mixamo/HeroMixamoXBot.glb` |

Los FBX fuente se guardan en `C:/Users/gabih/OneDrive/Escritorio/Mistborn/ActionForge` y el .glb se rearma con
**todos** sus FBX (el comando de cada archivo está en `git log` y en los comentarios de `scripts/core/art.gd`). Después:
`$G --headless --path . --import` y `git checkout -- project.godot`.

## 3. Retocar en ActionForge (si el clip no da justo)

```
"/c/Users/gabih/AppData/Local/Programs/actionforge-desktop/ActionForge.exe" --remote-debugging-port=9333 &
node tools/actionforge/export.mjs <clip> <salida.fbx> "posture:k0=0|0.42=0|0.57=-50,armSpace:k0=0|0.57=-20"
```
- Adjust solo funciona sobre clips de **su biblioteca**, no sobre importados.
- Claves: `parámetro:k<fracción del clip>=<grados>|<fracción>=<grados>`. `posture` negativo endereza el torso (pero
  sube los brazos: compensar con `armSpace`); `headPitch`; `armFwd`.
- Retocar solo donde hace falta (claves por tramo): un valor fijo en todo el clip arregla un momento y rompe otro.
- Ver `tools/actionforge/README.md`. Las capas de huesos quedan guardadas en la app y se cuelan en otras exportaciones.

## 4. Conectarlo

- Héroes: `scripts/character/hero_clips.gd`. `STATES`/`STANCES` (estado -> clip), `CUTS` (tramo [desde, hasta,
  golpe]), `HOLDS` (pose fija), `SKILLS` (poderes, capa de arriba: [clip, desde, hasta, suelta, velocidad fija,
  fundido final]). Comentar en la línea por qué ese clip y ese tramo.
- Zancada medida de cada clip de caminar o correr en `ModelRig.ANIM_STRIDE`.
- Lord Legislador: `scripts/npc/lord_powers.gd` (`CUTS`, `LENGTHS`, se sincroniza con el aviso). Otros: `Champion.KITS`.
- Un clip nuevo de otro archivo: que el personaje lo tenga como donante (`Art.hero_rig`: `extra_donors` y, para
  poderes, `upper_extra`).

## 5. Medir antes de mirar

| Qué | Prueba (`tools/anim_check/`) |
|---|---|
| Brazo durante un poder en el juego | `skill_arm.gd -- <poder>` |
| Saltos de pose en transiciones | `trans_film.gd` + `python tools/anim_check/saltos.py <log>` |
| Pies (flotan, se hunden, patinan) | `feet_check.gd` |
| Todo el combate por arma | `combat_film.gd` + `hoja_tramos.py` / `hoja_cuadros.py` |
| Dónde pega un golpe / a quién | `strike_check.gd`, `hit_check.gd` |
| Cuándo pega un clip (pico de la mano) | `clip_measure.gd` |

Criterios: ningún hueso a más del doble que en los cuadros vecinos; suela ±2 cm; pie apoyado patina < 0,3 m/s.

## Trampas que ya costaron horas

- **Pruebas que mienten**: el rig vuelve a activar su `_process` solo y pisa la pose con la de reposo. En toda prueba,
  `rig.set_process(false)` en cada cuadro, no una vez.
- **Saltos de 0 m/s seguidos de un pico**: es el ahorro de animación de los NPC lejanos (cada 4 cuadros) en headless,
  no un tirón real.
- **Probar sobre Vin**: `Art.player_model = "vin"` en la prueba; si no, carga el personaje guardado. Nunca llamar
  `change_character` en pruebas (guarda la elección del jugador).
- **Capa de arriba**: los poderes copian Spine2, cabeza y brazos; las piernas siguen en la guardia. Los brazos copian
  su dirección **en el mundo**: si el clip gira todo el cuerpo (los lanzamientos giran la cadera 60–145°), la mano
  pasa por la espalda. `ModelRig._twist_chest` gira Spine1 hacia el pecho del clip (tope 50°). Antes de elegir un
  clip, medir el giro de cadera del clip crudo.
  Tope propio por poder en `HeroClips.CHEST_TWIST` (encender metal: 20°).
- **Falsos saltos**: `saltos.py` marca la entrada de cada poder (0,12 s, rápida a propósito) y la del bloqueo. Un salto
  es real si aparece en medio del gesto o en un hueso que no participa.
- **Patinado al correr**: `feet_check` mide el tobillo; al correr mirar que "pie" ≈ "cuerpo", no la mediana de patina.
- **Dos estados con el mismo clip** (salto/aire): `_play` no mezcla; las poses fijas necesitan `seek(..., true)`.
- **Sin capa**: para filmar, ocultar `rig._cloak_anchor` (tapa el cuerpo).
- **Borrar temporales con rutas exactas**, nunca con comodines (el sistema lo bloquea).

## 6. Cerrar

- `python tools/anim_library.py` (regenera la biblioteca; sumar el clip a `CLIP_ORIGIN` si es de AF o Mixamo).
- Contar al usuario qué clip, de dónde, qué tramo y qué retoques, con los números medidos y lo que no se pudo.
- No commitear sin que lo pida; nunca `textures.rar`.
