# Plan: puntos en poderes en vez de en metales

Estado: plan para revisar. No hay código todavía. Responsable: Lucho (ver `docs/TAREAS.md`).

## 1. Cómo funciona hoy (lo que cambia)

- `Progression.metal_levels` guarda el nivel de cada metal (acero e hierro arrancan en 1 gratis, `FREE_METALS`).
  `points_total() = level - 1` y `points_spent()` suma niveles de metal × `point_cost` (atium 2).
- `SkillTree.SKILLS` dice qué nivel de metal pide cada poder. `is_unlocked` y `Player.skill_unlocked` comparan
  el nivel del metal con ese número.
- Las fórmulas reciben el nivel del metal: `fan_count`, `fan_angle`, `burst_dirs`, `shield_count`, `power_mass`, y
  el +3 % de fuerza por nivel de `SteelIron.level_boost`.
- La ventana K tiene un botón "+" por metal (`_raise_button`, `_other_metal_row`, `skill_tree_canvas._metal_card`).

## 2. Modelo de datos nuevo

**Una sola fuente de verdad:** el nivel de cada poder. Todo lo demás se calcula.

| Dato | Dónde | Qué es |
|---|---|---|
| `Progression.skill_levels: Dictionary` | progression.gd | `id -> 0..max`. Lo único que se guarda (más los metales transitorios). |
| `Progression.direct_levels: Dictionary` | progression.gd | **Temporal.** Niveles de los metales sin poderes (atium, cinc, cobre, bronce, latón), subidos directo como hoy. Se borra cuando esos metales tengan poderes. |
| `SKILLS[i]["tree"]` | skill_tree.gd | `&"allomancy"` o `&"feruchemy"`. Falta = alomancia. |
| `SKILLS[i]["max"]` | skill_tree.gd | Niveles del poder (hoy 5 en todos). Se lee con `SkillTree.max_level(id)`. |
| `SKILLS[i]["requires"]` | skill_tree.gd | Lista de requisitos extra, vacía por ahora (ver abajo). |
| `SkillTree.LAYOUTS` | se **mueve** de skill_tree_canvas.gd a skill_tree.gd | Posición y padres de cada poder. Pasa a ser dato del árbol porque de ahí sale el requisito, y la UI no puede ser la fuente. Clave: `[tree][metal]`. |

Cálculos (todos en `Progression`, estáticos):

```
skill_level(id)      = skill_levels.get(id, 0)
metal_level(m)       = suma de skill_level de todos los poderes de m (los dos árboles) + direct_levels.get(m, 0)
points_total()       = maxi(level, START_POINTS)      # START_POINTS = 3: 3 puntos en nivel 1-3, 4 en el 4… 100 en el 100
points_spent()       = suma de skill_levels × skill_cost(id)  +  suma de direct_levels × point_cost(m)
points_free()        = points_total() - points_spent()
```

- **Metal aprendido** = `metal_level(m) > 0`. `allomancy.can_burn` ya usa eso (`player.gd:340`): no cambia.
- **Feruquimia**: como `metal_level` filtra por metal sin mirar el árbol y `points_spent` suma todos los
  `skill_levels`, el segundo árbol comparte puntos y suma nivel de metal sin código extra. Solo hacen falta sus
  entradas en `SKILLS` y `LAYOUTS` con `"tree": &"feruchemy"`.
- `FREE_METALS`, `MAX_METAL_LEVEL` y `metal_cap` se van para los metales con poderes. Para los transitorios
  quedan con el mismo tope de hoy.

### Requisitos para poner un punto

```
can_raise_skill(id) = skill_level(id) < max_level(id)
                      and points_free() >= skill_cost(id)
                      and requirements_met(id)
requirements_met(id) = (sin padres en LAYOUTS, o padres = [&"root"])  o  TODOS los padres con nivel ≥ 1
                       and cada entrada de SKILLS[id]["requires"] se cumple
```

`requires` queda preparado para estos tipos, sin usarlos todavía:
`{"skill": id, "level": n}` (otro metal u otra rama), `{"player_level": n}`, `{"metal": m, "level": n}`.
Una sola función `_requirement_ok(r)` con un `match` por tipo: agregar uno nuevo es una línea.

### Bajar un punto (reasignar gratis)

- `lower_skill(id)`: resta 1 si ningún poder que depende de él (hijo en LAYOUTS o `requires`) quedaría sin su
  requisito. Si no se puede, la ventana dice cuál lo bloquea.
- `respec()`: devuelve todo y deja el inicio recomendado (los 3 puntos de abajo). Para quedar en cero se bajan a
  mano con "−". Están los dos: "−" por poder y "Devolver todos".
- Costo futuro: `refund_cost() -> int` que hoy devuelve 0 y se resta en `lower_skill` y `respec`. Es la única
  costura para cobrar más adelante.
- Al bajar, `prune_slots()` (ya existe) vacía las ranuras de poderes que quedaron en 0.

### Inicio

`reset()` deja `skill_levels = {steel_light_push: 1, iron_pull: 1, steel_combat_coin: 1}` (los 3 puntos
iniciales), Empuje en Q y Tirón en E como hoy. Acero e hierro quedan aprendidos porque tienen puntos, no por
`FREE_METALS`.

### Guardado

`user://progression.cfg`, sección `[poderes]` con `id = nivel` y `[metales_directos]` para los transitorios.
`ranuras/version = 5`. Archivos viejos: se ignora `[metales]` y se arranca con el inicio recomendado (las partidas
viejas no importan). Al cargar: cada nivel se acota a `0..max`, se descartan ids desconocidos y, si
`points_free() < 0` o un requisito no se cumple, `respec()` (lo mismo que hace hoy con un archivo editado a mano).

## 3. Fórmulas: del nivel del metal al nivel del poder

**Idea para no reescribir las fórmulas:** las funciones de hoy siguen recibiendo un "nivel equivalente" en la escala
vieja de 1-20. Una sola función traduce el nivel del poder (1-5) a esa escala:

```
equiv_level(id, lvl) = roundi(lerpf(unlock_viejo(id), 20, (lvl - 1) / (max_level(id) - 1)))
```

`unlock_viejo` es el `"level"` de hoy en `SKILLS` (se renombra `"legacy_level"`). Ejemplo: la Ráfaga
(desbloqueo viejo 3) en niveles 1-5 equivale a 3, 7, 12, 16, 20 → 3, 7, 11, 15, 19 monedas. Valores provisorios;
el balance se ajusta después cambiando la tabla, no las fórmulas.

| Fórmula | Hoy depende de | Pasa a | Usos a cambiar |
|---|---|---|---|
| `fan_count`, `fan_angle`, `burst_dirs` (Ráfaga) | nivel de acero | `equiv_level(steel_coin_burst)` | player.gd:1328-1329 (vista previa), 3075-3080 (disparo); tooltip |
| `fan_count`, `fan_angle` (Imán) | nivel de hierro | `equiv_level(iron_coin_magnet)` | player.gd:3921-3940; tooltip |
| `shield_count`, `shield_block_chance` (Escudo) | nivel de acero | `equiv_level(steel_coin_shield)` | player.gd:3115; tooltip |
| `power_mass` (peso que movés) | nivel de acero/hierro | nivel de Empuje básico (acero) o Tirón básico (hierro); Arrastre y Atracción usan el del Tirón | steel_iron.gd:213, player.gd:3571; tooltips de Empuje, Tirón, Arrastre, Atracción |
| `level_boost` +3 % de fuerza | nivel del metal | nivel de Empuje básico / Tirón básico (la Moneda de combate, el suyo) | steel_iron.gd:205 |
| `combo_tier` (combinadas 5/10/15) | nivel de los dos metales | **sigue en el metal** (ver D4: los umbrales cambian de sentido) | skill_tree.gd |
| Recargas y duraciones fijas (`*_COOLDOWN`, `*_TIME`, radios) | nada | sin cambio ahora; quedan listas para escalar con `skill_level` después | — |

**Regla:** cada poder escala solo con sus propios puntos. El metal escala aparte con los puntos que tiene en
poderes (de los dos árboles), y lo único que mejora es **el metal en sí: consumo y duración**, distinto para cada
metal. No hay tope en 20: la tabla del metal se define por puntos.

### Escalado de cada metal (nuevo)

Hoy `Allomancy.METALS` tiene `max` (reserva), `burn` y `flare` (consumo por segundo) fijos y `_process` resta
`rate * delta` (allomancy.gd:58). Se agrega una tabla provisoria por metal en `SkillTree`:

```
METAL_SCALING := {&"steel": {"burn": -0.02, "max": 0.03}, &"pewter": {"burn": -0.03, "max": 0.02}, ...}
# por punto en poderes del metal: consumo −2 % y reserva +3 % (acotados: consumo nunca menos del 40 %)
```

- `Allomancy` recibe un `metal_level: Callable` (igual que `can_burn`, player.gd:340) y multiplica `rate` y la
  reserva máxima por lo que da la tabla. Así sirve igual para NPC (sin callable = escala 1).
- La reserva máxima más grande hace que el mismo frasco dure más ("duración del metal"). Si se quiere que el frasco
  cargue más, `refill` ya usa `METALS[m]["max"]`: pasa a usar la reserva escalada.
- `combo_tier` (combinadas 5/10/15) sigue leyendo el nivel del metal; ver D4.

## 4. Lista de lugares a cambiar

**scripts/progression/progression.gd**
- Sacar `metal_levels` como dato guardado; agregar `skill_levels`, `direct_levels`, `START_POINTS`.
- Nuevas: `skill_level`, `can_raise_skill`, `raise_skill`, `can_lower_skill`, `lower_skill`, `refund_cost`.
- Cambian: `reset`, `metal_level`, `points_total`, `points_spent`, `respec`, `load_progress`, `save`.
- `can_raise`/`raise_metal` quedan solo para metales transitorios (comentario `shortcut:`).

**scripts/progression/skill_tree.gd**
- `SKILLS`: `"level"` → `"legacy_level"`, más `"max": 5`, `"tree"` y `"requires": []`.
- Recibe `LAYOUTS` (desde el canvas), con clave por árbol.
- Nuevas: `max_level`, `parents(id)`, `children(id)`, `requirements_met`, `equiv_level`, `skill_cost`.
- `is_unlocked(id)` = `Progression.skill_level(id) >= 1`.
- `tooltip_parts(id, metal_level)` → `tooltip_parts(id, skill_level)`: "Nivel 2/5", qué da el siguiente nivel y,
  si está bloqueado, "Necesita: Ráfaga de monedas" en lugar de "Se desbloquea en el nivel N".
- Textos de `DESCRIPTIONS` que dicen "por nivel de acero/hierro" en Ráfaga, Imán, Escudo y Moneda de combate.

**scripts/player/player.gd** (cambios puntuales, otros también lo editan)
- `skill_unlocked` (683): usa el nivel del poder; en red, `net_skill_levels`.
- `metal_level` (677): en red, calculado de `net_skill_levels`.
- Usos de fórmulas: 1328-1329, 3075-3080, 3115, 3921-3940 (tabla de arriba). 3571 queda igual.
- `_send_progress` / `_net_progress` (754-790): ver sección 6.

**scripts/allomancy/steel_iron.gd**: `level_boost` y `power_mass` leen el nivel de Empuje básico / Tirón básico
(o el del poder del agarre) en vez del metal.

**scripts/allomancy/allomancy.gd**: `metal_level: Callable`, consumo (58) y reserva (45, 110) escalados con
`SkillTree.METAL_SCALING`. Cambio puntual.

**HUD de metales (`MetalList`)**: la barra de reserva usa la reserva escalada.

**scripts/ui/skill_tree_window.gd** (vista Lista)
- `_column(metal)`: el encabezado muestra el nivel del metal calculado, sin botón "+".
- `_raise_button(metal)` → `_skill_buttons(id)`: "+" y "−" por poder, con indicador `0/5`, deshabilitados con el
  motivo en el tooltip (sin puntos, falta el poder previo, al máximo, un hijo depende de este).
- `_skill_row`: muestra `nivel/max`, gris si está en 0, el requisito si no se cumple.
- `_refresh_detail`: usa `tooltip_parts(id, skill_level)`.
- `_other_metal_row`: queda para los metales transitorios, marcado como temporal.
- Arriba, un selector **Alomancia | Feruquimia** (en feruquimia, columnas vacías con "Próximamente" hasta que
  tenga poderes). Los puntos libres son los mismos en las dos pestañas.
- Botón "Devolver todos los puntos" (`respec`, 211) queda igual.
- 325 (`coin_cap`) y 719 (asignar con tecla): siguen con `is_unlocked`.

**scripts/ui/skill_tree_canvas.gd** (vista Árbol)
- Lee `SkillTree.LAYOUTS[tree]`. Cada nodo dibuja sus pips `0/5`; clic o "+" sube, clic derecho baja.
- Líneas encendidas cuando el padre tiene nivel ≥ 1 (hoy, cuando el metal llega al nivel).
- `_metal_card` (260-291) y la placa del metal (370-394): sin botón, nivel calculado.

**scripts/ui/skill_row_label.gd**: `metal_level` → `skill_level`.

**scripts/ui/ability_hud.gd**: no cambia (usa `points_free` y `skill_unlocked`).

**scripts/ui/pause_menu.gd**
- `_set_level` (338): igual, con `respec` si faltan puntos.
- Agregar "Todos los poderes al máximo" y "Inicio recomendado" a la pestaña Personaje.
- Texto de ayuda (528, 533): cambiar "nivel + 1 monedas… en el nivel 15" por el nivel del poder.

**scripts/training/skill_room.gd**: guardar y devolver `skill_levels` y `direct_levels` en lugar de
`metal_levels`, y poner cada poder en su `max` mientras estás en la sala.

**tools/anim_check/aim_check.gd:16** y **aim_pitch_check.gd:19**: ponen `metal_levels` a mano. Pasar a poner
`skill_levels` del poder que prueban.

**docs/arbol-de-habilidades.md**: reemplazar las reglas de puntos por las nuevas.

## 5. Etapas (cada una se prueba sola)

Prueba nueva: `tools/anim_check/progression_check.gd`, sin escena, corre con
`--headless -s tools/anim_check/progression_check.gd` y sale con código 1 si falla una cuenta. Cada etapa le
suma sus casos.

| Etapa | Qué | Se verifica |
|---|---|---|
| 1. Datos | progression.gd y skill_tree.gd: `skill_levels`, cálculos, requisitos, inicio, guardado. LAYOUTS movido (el canvas lo lee de ahí). Los "+" por metal de la ventana siguen andando solo para transitorios. | progression_check: nivel 1 = 3 puntos y 0 libres; nivel 4 = 1 libre; acero e hierro aprendidos; poner un punto en Ráfaga sin Moneda de combate falla; `metal_level` suma; bajar un padre con hijo falla; guardar y cargar da lo mismo; un archivo con puntos de más vuelve al inicio. El juego arranca y K abre. |
| 2. Poderes y metal | player.gd y steel_iron.gd con `equiv_level`; `skill_unlocked` por poder; tooltips y textos. allomancy.gd con `METAL_SCALING`. | progression_check: Ráfaga 1-5 da 3, 7, 11, 15, 19 monedas; Escudo 1-5 da sus monedas. Acero con 0 y con 10 puntos: la reserva dura más con 10. En el juego, Ráfaga 1 y 5 se ven distintas. |
| 3. Ventana K, lista | "+" y "−" por poder, `0/5`, motivos, nivel del metal calculado, "Otros metales" temporal. | Subir y bajar desde K; el contador de puntos coincide con el HUD; no se puede bajar un padre con hijos. |
| 4. Ventana K, árbol | Pips, clic para subir, líneas por requisito. | Lo mismo que la 3, desde la vista Árbol. |
| 5. Trucos y sala | Menú Esc (máximo, inicio recomendado), sala de poderes, aim_check y aim_pitch_check. | Ctrl+F8 pone todo al máximo y al salir vuelve; las dos pruebas de mira corren. |
| 6. Feruquimia, esqueleto | `"tree"` en SKILLS, LAYOUTS por árbol, pestaña en K. Un poder de prueba de feruquimia en hierro, solo en progression_check. | progression_check: un punto en feruquimia de hierro sube el nivel del hierro y baja los puntos libres de los dos árboles. |
| 7. Red (después) | Ver sección 6. | — |

Un commit por etapa, en la rama de la tarea.

## 6. Red (anotado, no se hace ahora)

- `_send_progress` manda `skill_levels` como `PackedInt32Array` en el orden de `SKILLS` más los
  `direct_levels`, en lugar de los niveles de metal.
- `_net_progress` recalcula `points_spent`, acota cada nivel a `0..max`, comprueba requisitos y, si algo no
  cierra, deja al jugador con el inicio recomendado. Guarda `net_skill_levels`; `metal_level` remoto se calcula
  igual que en local (conviene una función estática `Progression.metal_level_of(levels, direct, m)` que usen las
  dos).
- Apagar metales que el cliente ya no tiene: igual que hoy.

## 7. Riesgos

- **player.gd lo editan varios.** Los cambios son 6 líneas sueltas; hacerlos al final de la etapa 2 y mergear
  develop antes.
- **LAYOUTS se mueve de archivo.** Si alguien edita el canvas en paralelo, conflicto. Moverlo en un commit solo.
- **Nivel del metal más alto que antes** (hasta 30 o más). Ahora solo escala consumo y reserva, con tope en la
  tabla; revisar que las combinadas (5/10/15) sigan teniendo sentido.
- **Pruebas de mira** que ponen niveles a mano dejan de compilar en la etapa 1 si no se cambian ahí mismo.

## 8. Decisiones abiertas

| # | Pregunta | Recomendación |
|---|---|---|
| D1 | ~~Devolver todos~~ | **Decidido:** vuelve al inicio recomendado. |
| D2 | ~~Dos padres~~ | **Decidido:** hacen falta todos los padres con al menos 1 punto. |
| D3 | ~~Tope del metal~~ | **Decidido:** cada poder escala con sus puntos; el metal, con los puntos en sus poderes, y mejora consumo y duración, distinto por metal. |
| D7 | Valores de `METAL_SCALING` para cada metal. | Arrancar igual para todos (−2 % consumo, +3 % reserva por punto) y diferenciarlos al balancear. |
| D4 | Las combinadas piden metal 5/10/15. Con la regla nueva, 5 = cinco puntos en poderes de ese metal. ¿Se mantiene? | Mantener los números y revisar al diseñar las combinadas. |
| D5 | ¿Cuesta lo mismo cada nivel de poder, o el atium sigue costando 2? | 1 punto todo; el atium transitorio sigue en 2 hasta que tenga poderes. |
| D6 | ~~Botón −~~ | **Decidido:** los dos, "−" por poder y "Devolver todos". |
