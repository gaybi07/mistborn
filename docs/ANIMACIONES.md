# Animaciones del nacido de la bruma

> Esto describe el modelo viejo del Mistborn de ActionForge. La lista al día de todos los clips, de dónde salen y qué usa
> cada acción de Vin y los demás héroes está en [BIBLIOTECA_ANIMACIONES.md](BIBLIOTECA_ANIMACIONES.md).

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

### Koloss que pelean (`assets/koloss/KolossMoves.glb`)

Clips de Mixamo (packs *Great Sword* y *Mutant*, más esquives y golpes), armados con
`mixamo_to_glb.py` y usados como donante con `BoneTools.MIXAMO_TO_UE` (ver `Art.koloss_fighter_rig`):
`gs_*` para el espadón y `mt_*` para las hachas y los poderes (`mt_roar`, `mt_flex`, `mt_jump_attack`).
Los clips van en el lugar: los que viajan los acompaña `Koloss` moviendo el cuerpo. `ANIM_STRIDE` de
`gs_*`/`mt_*` es para 1,8 m (`stride_scale` lo escala); sale de zancada del FBX × cadera del koloss /
cadera del clip (0,99 / 1,334). Con el espadón, `ModelRig._update_two_hand` lleva la mano izquierda al
mango. Se prueba con `tools/anim_check/koloss_check.gd` y, en el juego, con Mayús+F7.

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
| Puños 1 / 2 / 3 / remate | `attack_fist`, `_1`, `_2`, `_3` | `fist_jab`, `fist_cross`, `fist_uppercut`, `fist_roundhouse` | Mixamo | |
| Dagas 1 / 2 / 3 / remate | `attack_daggers`, `_1`, `_2`, `_3` | `dagger_lead`, `dagger_rear`, `fist_hook`, `dagger_double` | Mixamo | Puñaladas, el gancho como tajo cruzado y puñalada doble. |
| Espada y escudo 1 / 2 / remate | `attack_shield`, `_1`, `_2` | `shield_cross`, `shield_down`, `shield_kick` | Mixamo | |
| Espada 1 / 2 / remate | `attack_sword`, `_1`, `_2` | `sword_regular_a`, `_b`, `_c` | AF | Combo de 3 golpes (`player.gd`, `WEAPONS`). |
| Ataque en el aire | `attack_air` | `2H_Melee_Attack_Spinning` | KayKit | Giro de arma a dos manos. |
| Lanzar moneda | `throw` | `spell_simple_enter` | AF | Brazo extendido como lanzando un hechizo. |
| Recoger (bolsa, objetos, frascos) | `pickup` | `pickup_table` | AF | Solo parado o caminando (a la carrera se vería deslizándose). |
| Nadar / flotar quieto | `swim`, `swim_idle` | `swim_fwd`, `swim_idle` | AF | En el río donde el agua cubre más de 1,3 m (`Player._in_deep_water`). |
| Resbalar por una pendiente de más de 45° | `slide` | `slide` | AF | Godot cuenta esas pendientes como pared (`floor_max_angle`). |
| Empujar (acero) / tirar (hierro) | `allomancy` | `spell_simple_idle` + brazos con IK | AF + código | El brazo apunta al metal en código. |
| Recibir golpe flojo de frente | `hit_head`, `hit` | `hit_head`, `hit_chest` | AF | Se alternan. |
| Recibir golpe flojo de costado o espalda | `hit_left`, `hit_right`, `hit_back` | los mismos, tramo 0 a 0,2 | Mixamo | Capa superior: no empuja ni frena las piernas. |
| Recibir golpe fuerte | `hit_front`, `hit_back`, `hit_left`, `hit_right` | los mismos | Mixamo | Con avance del root. Aturdido: `hit_knockback`. |
| Muerto / noqueado | `down` | `death01` | AF | Cae de espaldas. |

Ya en el modelo pero sin usar (falta la mecánica): `hit_head`, `hit_knockback`, `laytoidle`
(levantarse), `slide_start` / `slide_exit` (entrar y salir del resbalón), `spell_simple_exit`,
`chest_open` (abrir cofre), `fixing_kneeling` (arreglar arrodillado).

En `Escritorio\Mistborn` y fuera del modelo: `sword_block` (no hay bloqueo), `sword_regular_a_rec` /
`b_rec` (recuperación al cortar el combo), `sword_regular_combo`, `walk_formal_loop`.

## Golpes de Mixamo (`assets/mixamo/MixamoCombat.glb`)

Se arma con `mixamo_to_glb.py`: los FBX sin piel más uno como modelo (donante con `BoneTools.MIXAMO_TO_UE`, en
`Art.player_rig`). De cada clip se usa solo el tramo del golpe (`ModelRig.ATTACK_CUT`, desde y hasta) e `IMPACT` dice
cuándo pega; para acelerar o frenar un golpe se cambia su duración en `Player.WEAPONS` o `SHIELD_COMBO`.

## Skaa en los barrios obreros (`scripts/npc/skaa_crews.gd`)

Cuadrillas por tipo de trabajo (`SkaaCrews.CREWS`) y barrio (`SkaaCrews.WORK`), con los clips `dig`, `kneel_*`,
`push_heavy`, `pull_heavy`, `lift_heavy`, `pick_up`/`carry_walk`/`put_down`, `sad_idle` y `warm_hands`. Modelos en
`Art.SKAA_MODELS`, armados con `rig_like_mistborn.py`. En los puestos de descanso, una nena (`SkaaGirl`,
modelo `SkaaPilgrim.glb`) con sus propios clips: `Walking_Woman` y `Arise`, que al revés es sentarse.

## Tiempos y mezcla (cómo está armado)

- **Impacto:** `ModelRig.IMPACT` guarda en qué fracción de cada clip pega el golpe (pico de velocidad de la mano o el
  pie, medido sobre el `.glb`). Los del koloss están en `Koloss.SWORD_BLOWS`. Clip nuevo de ataque: medirlo y agregarlo.
- **Capa superior:** `ModelRig.play_skill(clip, duración, desde, hasta)` juega el gesto solo en torso y brazos, sobre lo
  que hagan las piernas. Con `desde` y `hasta` se usa un tramo de un clip largo: `drink` (0,2 a 0,42), `burn_focus`
  (0,05 a 0,2), `pewter_flex` (0,25 a 0,68).
- **Clips sin desplazamiento propio:** los del koloss van en el lugar; `Koloss._strike` avanza el cuerpo hasta el último
  golpe del clip. Los de `ROOT_MOTION` sí traen el avance en el hueso root.
- **Quién le pega a quién:** el koloss a todo lo que no sea de su bando (`Koloss._victims`), el guardia a los koloss y a
  vos si lo provocaste, y la gente huye. El skaa que trabaja pasa a ser un `Citizen` al huir (`SkaaWorker._flee`).

## Lo que falta

| Acción | Estado actual | Buscar | Estado en `ANIMS` |
|---|---|---|---|
| Colgado de un borde | Pose de salto + IK | `braced hang`, `hanging idle` | `hang` |
| Ataque en el aire | `sword_regular_c` con giro | `jump attack` | `attack_air` |
| Arrastre de peltre (agotado) | Camina normal | `injured walk`, `tired` | nuevo estado |
| Dagas envainadas | No se ven sin desenvainar | — | código (engancharlas a `pelvis`) |

Las de "nuevo estado" y las que ya están en el modelo sin usar necesitan código (llamarlas desde
el `Player`); las demás funcionan solo con convertir el modelo y poner el nombre primero en su lista.

### Personajes de Meshy (`assets/meshy/`)

Con esqueleto de Mixamo (zip "All animation"): `tools/blender/meshy_to_glb.py`, varias tandas de clips del mismo personaje en un
solo `.glb`. Sin esqueleto (Kelsier, Vin; zip "texture", pose T): FBX a GLB y `tools/blender/rig_like_mistborn.py`, que les da el
esqueleto del Mistborn. Los NPC se usan con `Art.meshy_rig`; lo que un modelo no traiga sale de `MistbornHood.glb` y del Mistborn. Para jugar un clip con `play_spell` tiene que estar en `ModelRig.ANIMS`. `Walking` y `Running` pisan a 1,4 y 4,9 m/s para
1,8 m de alto (`ANIM_STRIDE`).

En el mapa (`Main._spawn_people`) solo están los personajes de Meshy, y cada uno se mueve únicamente con los clips de su paquete
(`ModelRig.clips_only`): el terrisano frente al taller de Clubs y los nobles en la plaza (`Art.CIVILIANS`); los obligadores en la plaza,
que no atacan hasta que les pegás; y afuera de las puertas (`GateForces`, solo con el jugador cerca) koloss al este, Lord Legislador al
oeste e inquisidores al sur (por ahora con el modelo encapuchado). Los skaa, guardias y alománticos de antes siguen en el código, sin
aparecer.

Los que pelean están en `Champion.KITS`: alto, vida, arma, clips de cada estado, combos (`blows`) y poderes (`powers`). `hits` y `at` son
los picos de velocidad de la mano, medidos en cada clip y revisados en hojas de cuadros: el golpe llega cuando la mano llega. Los
efectos están apagados (`Fx.ENABLED`) hasta sumarlos clip por clip. Mayús+F7 trae a cada uno, de a uno, para probarlo. Ningún paquete
trae un clip de recibir un golpe: por ahora la reacción es el destello y la pausa del golpe.

El jugador se elige con P (`Art.HEROES`): el Mistborn encapuchado y el terrisano (todavía sin ferruquimia). Kelsier y Vin esperan en
`Art.HEROES_LATER` hasta tener sus clips. Se mueven con los clips del paquete `MistbornHood.glb` y mezclas entre ellos; el terrisano usa
primero los suyos: `scripts/character/hero_clips.gd` dice qué clip y qué tramo usa cada acción. Sin clip, no hay movimiento: no se
generan poses por código.
