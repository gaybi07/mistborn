# Mistborn (Godot 4.7)

Responder en español rioplatense. Repo `gaybi07/mistborn`; no commitear ni pushear sin que se pida, y nunca
`textures.rar`. Otras sesiones y un amigo editan `model_rig.gd`, `player.gd`, `humanoid_rig.gd`, `npc.gd` y
`metal_bar.gd`: cambios puntuales, sin reescribir.

Godot: `/c/Users/gabih/Downloads/Godot/Godot_v4.7.2-stable_win64_console.exe`. Abrirlo modifica `project.godot`:
después de cada corrida, `git checkout -- project.godot`.

## Animaciones

1. **Solo clips reales** (Meshy, Mixamo, ActionForge), retocados: tramo, velocidad, pose fija, Adjust o rotaciones en
   ActionForge. Nada generado por código. Preferir los de Meshy (mismo esqueleto que los héroes); los FBX de Mixamo
   bajados aparte quedan con los codos abiertos. Bajar algo nuevo pide permiso.
2. **Probar sobre el personaje elegido** (Vin): forzar `Art.player_model = "vin"` en las pruebas, si no se carga el
   guardado (el encapuchado). No llamar `change_character` en pruebas: guarda la elección del jugador.
3. **Medir antes y después** con `tools/anim_check/` (ver su README):
   - saltos de pose: ningún hueso a más del doble que en los cuadros vecinos (`saltos.py`);
   - pies: suela a ±2 cm del piso; el pie apoyado patina menos de 0,3 m/s (`feet_check.gd`);
   - golpes: lo que pega está adelante y a su alcance en el cuadro del impacto (`strike_check.gd`).
4. **Toda transición mezcla**: entrar rápido (0,08–0,16 s), salir más lento (~0,3 s). Ojo con dos estados que usan
   el mismo clip (salto/aire/aterrizaje): `_play` cree que no cambió y no mezcla.
5. **Zancada medida** de cada clip de locomoción en `ModelRig.ANIM_STRIDE`; un clip que habría que acelerar más de
   2,2× no sirve para esa velocidad.
6. **Golpes**: el daño cae en el pico de velocidad de la mano (`HeroClips.CUTS`, tercer valor) y donde está de verdad
   el puño, la hoja o el pie (`ModelRig.strike_points`).
7. **Revisión visual**: sin capa (tapa el cuerpo), en hojas de cuadros, con las cuatro armas (puños, dagas, espada,
   espada y escudo) y todos los casos: quieto, caminar, correr, agacharse, saltar, caer, rodar, combo, poderes.
8. **Registro**: al cambiar un clip, comentar en `hero_clips.gd` por qué, y regenerar
   `docs/BIBLIOTECA_ANIMACIONES.md` con `python tools/anim_library.py`.
9. No subir trabajo de animación hasta que el usuario lo pruebe.
