# Guía: personaje y animaciones con Mixamo → Godot 4.7

Objetivo: sustituir el cuerpo procedural (`HumanoidRig`) del alomántico por un modelo con esqueleto
y animaciones reales (rodar, trepar, nadar, escaleras, bloquear, combate...), sin perder lo que ya
funciona: capa de bruma, armas, líneas de acero/hierro, atium, etc.

Flujo completo:

```
Modelo (Hunyuan3D / Blender / personaje de Mixamo)
   → Mixamo: auto-rig (esqueleto automático)
   → Mixamo: descargar animaciones
   → Godot: importar con BoneMap (retarget humanoide)
   → AnimationTree (máquina de estados)
   → conectar al Player (yo lo hago cuando tengas los archivos)
```

---

## 1. Conseguir el modelo del personaje

Tienes tres opciones, de más rápida a más personalizada:

| Opción | Cuándo usarla |
|---|---|
| **Personaje de Mixamo** (pestaña *Characters*, p. ej. "Y Bot") | Para probar ya las animaciones en el juego. Luego cambias el modelo sin rehacer nada. |
| **Hunyuan3D** (tu carpeta `Proyectos\Hunyuan`) a partir de una imagen de concepto | Para tener *tu* nacido de la bruma con su estilo. |
| **Blender** a mano | Control total, más trabajo. |

### Si generas el modelo con Hunyuan3D

1. Haz una imagen de concepto **de cuerpo entero, de frente, en pose T o A** (brazos separados del
   cuerpo, piernas un poco abiertas), fondo liso. Sin capa larga ni armas: esas piezas las pone el
   juego (la capa de tiras es procedural y ondea con la física; las armas se enganchan a la mano).
2. Genera el modelo y expórtalo en `.glb` u `.obj`.
3. Ábrelo en **Blender** y límpialo:
   - Una sola malla (selecciona todo → `Ctrl+J`).
   - Escala real: ~1,75 m de alto. Pies en el suelo (Z = 0), mirando hacia **-Y** en Blender.
   - `Ctrl+A → All Transforms` para aplicar posición, rotación y escala.
   - Si tiene muchos polígonos, modificador **Decimate** hasta ~20–40 mil triángulos.
   - Exporta en **FBX** (`File → Export → FBX`, *Apply Transform* activado).

> Consejo de estilo (medieval + bruma + toque cyberpunk): ropa oscura y apagada, y como mucho
> algún detalle que brille (costuras, runas, los frascos del cinturón). El color fuerte lo pone la
> alomancia, igual que en el juego actual.

---

## 2. Auto-rig en Mixamo

1. Entra en <https://www.mixamo.com> con una cuenta de Adobe (gratuita).
2. **Upload Character** → arrastra tu `.fbx` (o `.obj`).
3. Coloca los marcadores: **barbilla, muñecas, codos, rodillas e ingle**.
4. **Skeleton LOD: Standard Skeleton (65)**. Si las manos no tienen dedos separados, elige
   *No Fingers*.
5. Revisa la previsualización: si las axilas o las rodillas se deforman mal, vuelve atrás y
   recoloca los marcadores.

Si usas un personaje de Mixamo, salta este paso.

---

## 3. Descargar: primero el personaje, luego las animaciones

**El personaje (una sola vez):**

- Elige cualquier animación (o ninguna) → **Download**.
- Format: **FBX Binary (.fbx)** · Skin: **With Skin** · Frames per second: **30** · Keyframe
  Reduction: **none**. Pose: **T-pose** (si te lo ofrece).
- Nombre: `allomancer.fbx`.

**Cada animación:**

- Format: **FBX Binary** · Skin: **Without Skin** (pesan mucho menos y comparten el esqueleto).
- 30 fps, sin reducción de keyframes.
- **In Place** activado en todas las de desplazamiento (caminar, correr, rodar, dash, nadar...):
  el juego ya mueve al personaje con la física; si la animación también avanza, se "patina".
- Nombra cada archivo con un nombre corto en inglés o español, sin espacios: `idle.fbx`,
  `run.fbx`, `roll.fbx`...

---

## 4. Lista de animaciones a buscar

Escribe la palabra clave en el buscador de Mixamo. Los nombres exactos cambian a veces, así que
prueba variantes; marca **In Place** cuando aparezca la casilla.

### Movimiento básico
| Para | Buscar | Archivo |
|---|---|---|
| Reposo | `idle`, `breathing idle` | `idle.fbx` |
| Caminar | `walking` | `walk.fbx` |
| Correr | `running` | `run.fbx` |
| Esprintar (peltre) | `sprint`, `fast run` | `sprint.fbx` |
| Girar en el sitio | `left turn 90`, `right turn 90` | `turn_left.fbx`, `turn_right.fbx` |
| Saltar | `jump`, `running jump` | `jump.fbx`, `jump_run.fbx` |
| Cayendo | `falling idle` | `fall.fbx` |
| Aterrizar | `hard landing`, `falling to landing` | `land.fbx` |
| Aterrizar rodando | `falling to roll` | `land_roll.fbx` |

### Esquivas y movilidad
| Para | Buscar | Archivo |
|---|---|---|
| Voltereta | `sprinting forward roll`, `stand to roll` | `roll.fbx` |
| Esquivar | `dodging`, `standing dodge left/right/backward` | `dodge_l.fbx`, `dodge_r.fbx`, `dodge_back.fbx` |
| Dash | `running slide`, `dash` | `dash.fbx` |
| Subir/bajar escaleras | `ascending stairs`, `descending stairs` | `stairs_up.fbx`, `stairs_down.fbx` |
| Trepar | `climbing`, `climbing up wall`, `braced hang`, `hanging idle`, `climbing ladder` | `climb.fbx`, `hang.fbx`, `ladder.fbx` |
| Subir a una cornisa | `climbing to top`, `braced hang to crouch` | `ledge_up.fbx` |
| Nadar | `swimming`, `treading water` | `swim.fbx`, `swim_idle.fbx` |

### Alomancia
No hay animaciones "de alomancia", pero estas quedan muy bien:
| Para | Buscar | Archivo |
|---|---|---|
| Empujar (acero) | `standing 1h magic attack`, `magic spell`, `push` | `steel_push.fbx` |
| Tirar (hierro) | `pulling`, `standing 2h magic area attack` | `iron_pull.fbx` |
| Lanzar moneda | `throw`, `toss` | `throw.fbx` |
| En el aire empujando | `falling idle` + brazo apuntando con IK (lo hago en código) | — |

### Combate
| Para | Buscar | Archivo |
|---|---|---|
| Guardia con espada | `sword and shield idle`, `great sword idle` | `sword_idle.fbx` |
| Tajos de espada | `sword and shield slash`, `outward slash`, `inward slash` | `sword_slash_1.fbx`, `_2`, `_3` |
| Dagas | `dual weapon`, `knife attack`, `stabbing` | `dagger_1.fbx`, `_2` |
| Puñetazos (peltre) | `punching`, `cross punch`, `hook punch` | `punch_1.fbx`, `_2` |
| Bloquear | `sword and shield block`, `standing block idle` | `block.fbx` |
| Recibir golpe | `hit reaction`, `standing react` | `hit.fbx` |
| Morir / caer | `dying`, `falling back death` | `death.fbx` |

> Mixamo tiene **packs** (búscalos con la palabra *pack*, por ejemplo `sword and shield pack`)
> que traen muchas animaciones del mismo estilo de una vez: suelen encajar mejor entre sí que
> animaciones sueltas.

---

## 5. Importar en Godot 4.7

1. Crea las carpetas y copia los archivos:
   ```
   assets/characters/allomancer/allomancer.fbx
   assets/characters/allomancer/anims/idle.fbx, run.fbx, roll.fbx...
   ```
2. En Godot, doble clic sobre `allomancer.fbx` → **Advanced Import Settings**:
   - Selecciona el nodo **Skeleton3D** → *Retarget → Bone Map* → **New BoneMap** →
     *Profile*: **SkeletonProfileHumanoid**. Los huesos `mixamorig:*` se asignan solos (deben
     quedar en verde).
   - Activa *Retarget → Rest Fixer → Overwrite Axis* y *Fix Silhouette*.
   - Guarda el BoneMap como `assets/characters/allomancer/bonemap.tres` y pulsa *Reimport*.
3. Para **cada animación** (puedes seleccionar varias a la vez en el panel *Import*):
   - *Import As*: **Animation Library**.
   - Mismo **BoneMap** (`bonemap.tres`) en *Retarget*.
   - Las de bucle (idle, walk, run, sprint, fall, swim, hang, climb...): en
     *Advanced → Animation → Loop Mode*: **Linear**.
   - *Reimport*.
4. Comprueba una: instancia `allomancer.fbx` en una escena de prueba, añade la librería al
   `AnimationPlayer` y reproduce `run`. Si el personaje se hunde o flota, revisa el paso 1 de
   Blender (pies en Z = 0).

---

## 6. Máquina de estados (AnimationTree)

Así la montaré (te la dejo descrita por si quieres hacerla tú en el editor):

```
StateMachine
├── Locomotion   (BlendSpace1D por velocidad: idle 0 · walk 2 · run 6 · sprint 12)
├── Air          (jump → fall → land / land_roll)
├── Roll / Dodge / Dash   (OneShot)
├── Climb        (hang ↔ climb, ledge_up)
├── Swim         (swim_idle ↔ swim)
└── Death
Capa superior del cuerpo (Blend2 con filtro: columna, brazos, cabeza)
├── Ataques (sword_slash_1..3, dagger_1..2, punch_1..2)  → OneShot
├── Block
└── Steel push / Iron pull / Throw
```

La **capa superior** permite atacar o empujar mientras corres: las piernas siguen con la
locomoción y solo el tronco y los brazos hacen el ataque.

---

## 7. Cómo se conecta con el juego actual

El `Player` ya le pasa al cuerpo todo lo necesario cada frame (velocidad, si está en el suelo,
velocidad vertical, objetivos de empuje y tirón, armas, ataques, voltereta). Lo que haré:

1. Un script `MixamoRig` con **la misma interfaz que `HumanoidRig`** (`move_speed`, `on_floor`,
   `aim_target`, `play_attack()`, `play_roll()`, `set_weapon()`...), que en vez de mover piezas
   cambia de estado en el `AnimationTree`.
2. En `player.gd` se cambia **una línea**: `HumanoidRig.new()` → la escena del modelo.
3. **Capa de bruma**: se engancha al hueso `Spine2` con un `BoneAttachment3D`. Las tiras siguen
   siendo procedurales y reaccionan a la velocidad igual que ahora.
4. **Armas**: las dagas y la espada actuales se enganchan a `RightHand`/`LeftHand` con
   `BoneAttachment3D`; envainadas, a `Hips`.
5. **Brazos apuntando al metal** al empujar o tirar: un modificador de esqueleto (IK /
   `LookAtModifier3D`) sobre los brazos, mezclado encima de la animación.
6. **Trepar, nadar y escaleras** necesitan, además de la animación, detectar el mundo:
   - Trepar: rayos hacia delante y hacia arriba para encontrar cornisas.
   - Nadar: zonas de agua (`Area3D`) que cambian el estado.
   - Escaleras: detectar escalones o rampas y elegir `stairs_up`/`stairs_down`.

   Eso también lo programo cuando estén las animaciones.

---

## 8. Qué necesito que me pases

- [ ] `assets/characters/allomancer/allomancer.fbx` (con piel)
- [ ] La carpeta `anims/` con las animaciones de la sección 4 (aunque sean solo las básicas
      para empezar: idle, walk, run, jump, fall, land, roll, una de ataque)
- [ ] Dime si las importaste con el BoneMap o prefieres que lo configure yo

Con eso conecto el modelo al juego, las mecánicas siguen funcionando igual y vamos añadiendo
animaciones por tandas.
