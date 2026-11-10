# Registro de tareas terminadas

Lo agrega la skill `tarea` al mergear cada tarea a develop. Lo más nuevo, arriba.

### 2026-11-10 · G3 · Espectro de la bruma · Gabi
- **Rama:** `gabi/g3-espectro-bruma` (borrada) · **Merge:** `50d9b37`
- **Qué se hizo:** el modelo de Meshy ("The Marrow Mist": masa de bruma con esqueletos adentro, sin esqueleto propio)
  en `assets/meshy/Espectro.glb`. Como no se puede riggear, lo mueve un shader (`shaders/mist_wraith.gdshader`):
  respira y ondula, se arrastra a tirones, se echa atrás y se lanza (pega en el pico del estirón) y al morir se
  derrite en bruma. Enemigo `MistWraith` (bando de los koloss, 70 de vida, 1,9 a 2,6 m) con cuerpo `WraithRig`.
  Seis en las afueras (camino del oeste y borde del bosque), por GateForces.
- **Archivos:** `scripts/npc/mist_wraith.gd`, `scripts/character/wraith_rig.gd`, `shaders/mist_wraith.gdshader`
  (nuevos), `scripts/core/art.gd`, `scripts/npc/gate_forces.gd`.
- **Cómo se probó:** `tools/world/wraith_check.gd` pasa (se arrastra, se lanza, pega 14, se derrite y desaparece);
  fotos. No se jugó con teclado: Gabi lo deja para revisar al terminar la historia (G21).
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** G21 (revisar cómo se mueve y los FPS). Excepción a la regla de clips reales: este bicho
  no tiene cuerpo para riggear (decisión del 10/11).

### 2026-11-10 · G2 · Foso de ceniza · Gabi
- **Rama:** `gabi/g2-foso-ceniza` (borrada) · **Merge:** `6e9db37`
- **Qué se hizo:** foso de trabajo forzado al oeste de Luthadel (-580, 330): unos 200 m de ancho y 40 m de hondo,
  cuatro paredes con terrazas y rampas en espiral; borde irregular, terrazas que ondulan, espolones que cortan
  terrazas y picos de roca en el fondo; lomas alrededor. Empalizada, torres, barracas, fogatas y carros (Quaternius),
  cuadrillas skaa y 6 soldados. Las lomas del exterior ya no lo tapan. Misiones: cartel en la plaza que se lee con E,
  objetivo escrito bajo la brújula, marcador en pantalla de adónde ir, y segunda misión de prueba de Dockson
  (`prueba_foso`) que te manda al foso.
- **Archivos:** `scripts/world/ash_pit.gd` (nuevo), `city_plan.gd`, `exterior.gd`, `scripts/npc/` (gate_forces,
  skaa_crews), `scripts/story/` (story, quest_log, dialogues, quest_tracker), `scripts/ui/` (waypoint_marker nuevo,
  compass_bar, dialogue_box, hud), `terrain/data` regenerado.
- **Cómo se probó:** `tools/world/pit_check.gd` (se llega caminando al fondo; guardias en su lugar) y
  `tools/story/quest_check.gd` pasan; fotos sin bruma. Gabi lo dio por bueno sin jugar el foso nuevo con teclado.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** modelos propios del foso en G20 (Meshy); el foso queda fuera del mapa de la ciudad (región
  en G6/G7); imágenes de referencia del foso, si llegan, para retocarlo. `story_check` falla por los poderes del
  final (no es de esta tarea).

### 2026-11-09 · G1 · Conversaciones, cuaderno, marcas del mapa y guardado · Gabi
- **Rama:** `gabi/g1-dialogos-guardado` (borrada) · **Merge:** `995558a`
- **Qué se hizo:** conversaciones con opciones y "[E] Hablar con"; estado de la historia con misiones por pasos;
  cuaderno (J); brújula arriba; marcas en mapa y minimapa con flechas al borde y tipos que se ocultan; quien tiene
  una misión para darte figura en mapa, brújula y cuaderno; tres partidas con pantalla de inicio y Esc → Partidas,
  guardado al terminar misión y al salir. El mapa ahora muestra las casas sin bruma. Misión de prueba `prueba_plaza`
  (Dockson y el cartel de la plaza).
- **Archivos:** `scripts/story/` (quest_log, dialogues, quest_tracker, save_slots), `scripts/ui/` (dialogue_box,
  journal_window, compass_bar, start_screen, city_map, hud, pause_menu), `scripts/main.gd`, `scripts/core/input_setup.gd`
- **Cómo se probó:** `tools/story/quest_check.gd` pasa completo; Gabi la jugó: misión, mapa y partidas andan.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** marcas de rumor ("?") y misiones reales en G5; mapa de región con G6/G7; red (L21).
  La plaza sale oscura en la foto del mapa. Toca `hud.gd`, `pause_menu.gd` y `city_map.gd` (interfaz, cerca de Lucho).

### 2026-11-09 · G0 · Base para repartir las tareas · Gabi
- **Rama:** `escenarios-y-jugabilidad` (anterior a este sistema; sigue existiendo) · **Commit:** `d9bba6a`, develop
  avanzado sin merge
- **Qué se hizo:** capa de la bruma de Vin hecha en Blender, plan de progresión por poderes
  (`docs/PLAN_PROGRESION.md`), tareas de cada uno (`docs/TAREAS.md`) y skills de Blender del proyecto.
- **Cómo se probó:** el juego corre sin ventana sin errores de script.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** Lucho arranca con L1.
