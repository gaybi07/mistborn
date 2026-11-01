# Animaciones del nacido de la bruma

Qué animación usa cada acción del jugador cuando lleva un modelo de Mixamo (`Art.PLAYER_MODELS`),
de dónde sale y cuáles faltan. La elección está en `ModelRig.ANIMS`
(`scripts/character/model_rig.gd`): para cada estado se prueba una lista de nombres y se usa el
primero que exista, primero en el modelo y si no en el donante (KayKit `Rogue.glb`, copiado al
esqueleto de Mixamo con `BoneTools.KAYKIT_TO_MIXAMO`).

## Cambiar el modelo por uno nuevo (pose T, sin esqueleto)

1. **Blender**: una sola malla, ~1,75 m, pies en Z = 0, mirando a -Y, `Ctrl+A → All Transforms`.
   Exporta FBX.
2. **Mixamo** → *Upload Character* → marcadores (barbilla, muñecas, codos, rodillas, ingle) →
   *Standard Skeleton (65)*. Descarga: FBX Binary, **With Skin**, T-pose, 30 fps.
   El esqueleto tiene que ser el de Mixamo: el retarget busca huesos con esos nombres (`Hips`,
   `Spine2`, `LeftArm`...).
3. **Convertir** a `.glb`, junto con las animaciones propias de Mixamo que ya usabas (las FBX
   *Without Skin* sirven para cualquier personaje de Mixamo; no hace falta volver a bajarlas):
   ```
   blender -b -P tools/blender/mixamo_to_glb.py -- assets/mixamo/Mistborn.glb mistborn.fbx Climbing.fbx Jumping_Down.fbx
   ```
4. **`scripts/core/art.gd`**: añade `"mistborn": "res://assets/mixamo/Mistborn.glb"` a
   `PLAYER_MODELS` y pon `static var player_model := "mistborn"`.

### Con ActionForge (el `Mistborn.glb` actual)

El modelo de Hunyuan3D se riguea y anima en <https://actionforge.app> (rig de Quaternius, CC0).
Cada animación se baja como un `.glb` con el personaje (`<nombre>_adjusted_fit.glb`). Se juntan
todas en uno:

```
blender -b -P tools/blender/actionforge_to_glb.py -- assets/mixamo/Mistborn.glb idle_loop_adjusted_fit.glb walk_loop_adjusted_fit.glb ...
```

El esqueleto tiene nombres tipo Unreal (`pelvis`, `upperarm_l`...); lo que falta se toma de KayKit
con `BoneTools.KAYKIT_TO_UE` (se elige en `Art.PLAYER_MODELS`). Las animaciones pierden `_loop` del
nombre (`sprint_loop` → `sprint`). Para añadir una nueva, vuelve a correr el comando con todos los
archivos (los fuente están en `Escritorio\Mistborn`) y pon su nombre primero en `ModelRig.ANIMS`.

Corregidas en el Motion Lab de ActionForge, con el `Mistborn.glb` cargado como personaje (salen ya
en su esqueleto), en `Escritorio\Mistborn\af_fixed`: `walk`, `sprint`, `sad_walk`, `carry_walk`,
`crouch_walk` con *Foot lock* (ojo: solo se aplica si el ciclo está *adjusted*, o sea con algún valor
de Gait cambiado), y los esquives y golpes de Mixamo (`dodge_*`, `hit_*`). Van en el comando de arriba
en lugar de `walk_loop` y `sprint_loop`; después se regenera el skaa con
`tools/blender/rig_like_mistborn.py`. Esquives y golpes se desplazan de verdad (1 a 1,7 m): conservan
el root (`ROOT_MOTION` en el script y en `ModelRig`) y el juego mueve al personaje con ese avance.

Todo lo que el modelo no traiga lo toma de KayKit automáticamente. Para añadir una animación
nueva: bájala de Mixamo, añádela al comando del paso 3 y pon su nombre (el del archivo, con `_`
en vez de espacios) **primero** en la lista de su estado en `ModelRig.ANIMS`.

## Lo que hay ahora

Origen: **AF** = ActionForge, propia del modelo (`Mistborn.glb`) · **KayKit** = prestada con
retarget (personaje chibi: en un cuerpo realista los brazos pueden quedar cortos y la postura rígida).
Las dagas de obsidiana y la espada se enganchan a los huesos de las manos (`ModelRig._attach_weapons`).

| Acción del jugador | Estado | Animación usada | Origen | Nota |
|---|---|---|---|---|
| Quieto | `idle` | `idle` | AF | Piernas abiertas, en guardia. |
| Quieto con arma | `idle_armed` | `sword_idle` | AF | Guardia baja con el arma. |
| Caminar | `walk` | `walk` | AF | Solo se ve al arrancar o frenar (el jugador va a 6 m/s). |
| Correr / esprintar (peltre) | `run`, `sprint` | `sprint` | AF | Se acelera con la velocidad. |
| Huir (NPC) | `flee` | `Running_B` | KayKit | |
| Saltar | `jump` | `jump_start` | AF | Empieza agachado: el impulso del juego es inmediato, así que se agacha ya en el aire. |
| En el aire / volando con acero | `air` | `jump` | AF | Misma pose para caer, subir empujado y planear. |
| Aterrizar | `land` | `jump_land` | AF | Sin versión de caída fuerte. |
| Voltereta (suelo) | `roll` | `roll` | AF | |
| Dash en el aire | `dash` | `sword_dash` | AF | Estocada hacia delante. |
| Colgado de un borde | `hang` | `Jump_Idle` + brazos con IK | KayKit + código | Provisional. |
| Subir el borde | `climb` | `Jump_Start` | KayKit | Provisional. |
| Puños 1 / 2 / remate | `attack_fist`, `_1`, `_2` | `Unarmed_Melee_Attack_Punch_A`, `Punch_A`, `Unarmed_Melee_Attack_Kick` | KayKit | Golpes 1 y 2 son el mismo puñetazo. |
| Dagas 1 / 2 / 3 / remate | `attack_daggers`, `_1`, `_2`, `_3` | `sword_regular_a`, `_b`, `sword_attack`, `sword_regular_c` | AF | |
| Espada 1 / 2 / remate | `attack_sword`, `_1`, `_2` | `sword_regular_a`, `_b`, `_c` | AF | Combo de 3 golpes (`player.gd`, `WEAPONS`). |
| Ataque en el aire | `attack_air` | `2H_Melee_Attack_Spinning` | KayKit | Giro de arma a dos manos. |
| Lanzar moneda | `throw` | `spell_simple_enter` | AF | Brazo extendido como lanzando un hechizo. |
| Recoger (bolsa, objetos, frascos) | `pickup` | `pickup_table` | AF | Solo parado o caminando (a la carrera se vería deslizándose). |
| Nadar / flotar quieto | `swim`, `swim_idle` | `swim_fwd`, `swim_idle` | AF | En el río donde el agua cubre más de 1,3 m (`Player._in_deep_water`). |
| Resbalar por una pendiente de más de 45° | `slide` | `slide` | AF | Godot cuenta esas pendientes como pared (`floor_max_angle`). |
| Empujar (acero) / tirar (hierro) | `allomancy` | `spell_simple_idle` + brazos con IK | AF + código | El brazo apunta al metal en código. |
| Recibir golpe | `hit` | `hit_chest` | AF | |
| Muerto / noqueado | `down` | `death01` | AF | Cae de espaldas. |

Ya en el modelo pero sin usar (falta la mecánica): `hit_head`, `hit_knockback`, `laytoidle`
(levantarse), `slide_start` / `slide_exit` (entrar y salir del resbalón), `spell_simple_exit`,
`chest_open` (abrir cofre), `fixing_kneeling` (arreglar arrodillado).

En `Escritorio\Mistborn` y fuera del modelo: `sword_block` (no hay bloqueo), `sword_regular_a_rec` /
`b_rec` (recuperación al cortar el combo), `sword_regular_combo`, `walk_formal_loop`.

## Lo que falta

| Acción | Estado actual | Buscar | Estado en `ANIMS` |
|---|---|---|---|
| Colgado de un borde | Pose de salto + IK | `braced hang`, `hanging idle` | `hang` |
| Subir el borde | Inicio de salto | `climbing`, `climb up` | `climb` |
| Caer (distinto de subir) | `jump` para todo | `falling idle` | `air` |
| Ataque en el aire | Giro de KayKit | `jump attack` | `attack_air` |
| Puños | KayKit | `punch`, `kick` | `attack_fist`, `_1`, `_2` |
| Aterrizaje fuerte (caída larga con peltre) | Mismo aterrizaje | `hard landing` | nuevo estado |
| Tirar con hierro | Igual que empujar | `pull` | nuevo estado `pull` |
| Beber frasco | Ninguna | `drinking` | nuevo estado |
| Arrastre de peltre (agotado) | Camina normal | `injured walk`, `tired` | nuevo estado |
| Dagas envainadas | No se ven sin desenvainar | — | código (engancharlas a `pelvis`) |

Las de "nuevo estado" y las que ya están en el modelo sin usar necesitan código (llamarlas desde
el `Player`); las demás funcionan solo con convertir el modelo y poner el nombre primero en su lista.
