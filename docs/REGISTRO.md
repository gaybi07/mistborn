# Registro de tareas terminadas

Lo agrega la skill `tarea` al mergear cada tarea a develop. Lo más nuevo, arriba.

### 2026-11-10 · G7 · Campamento koloss · Gabi
- **Rama:** `gabi/g7-campamento-koloss` (borrada) · **Merge:** `fe077b8` · **Estado:** 🧪 falta revisar (ronda 2)
- **Qué se hizo:** campamento koloss en un claro al norte del camino de la Puerta Este, centrado en (640, -330) (se
  corrió del punto viejo, que caía sobre el camino): empalizada de estacas rota a tramos, unas 57 tiendas de cuero en
  corros alrededor de fogatas, hoguera en el centro, pilas de huesos, estantes de carne, la carga apilada que llega por
  la entrada y cuatro torres de vigía. Ocho koloss (dos adultos) junto a las fogatas, por GateForces (ahora sabe poner
  koloss). El lugar `campamento` de la historia queda listo.
- **Archivos:** `scripts/world/koloss_camp.gd` (nuevo), `scripts/main.gd`, `scripts/world/exterior.gd`,
  `scripts/npc/gate_forces.gd`, `scripts/story/story.gd`.
- **Cómo se probó:** fotos sin bruma (desde arriba, en diagonal, la entrada, la hoguera y las tiendas); el juego corre
  sin errores. Sin jugar.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** modelos propios en G24 (los pasa Gabi); la misión "rastros" (Acto 2) llega con su acto;
  ronda 2.

### 2026-11-10 · G6 (arreglo) · Aldeas del Camino Sur, pueblo grande · Gabi
- **Rama:** `gabi/g6-aldea-grande` (borrada) · **Merge:** `3e41809` · **Estado:** 🧪 falta revisar (ronda 2)
- **Qué se hizo:** pedido de Gabi: pueblos chico 50, mediano 100, grande 300 casas; densos, no pobres; con fortificación,
  mansión noble y zona de granjas. Las Aldeas del Camino Sur pasan a pueblo grande: 304 casas (178 adentro de la
  muralla, el resto en arrabales y caseríos), muralla de piedra con torres y entradas, calles en cuadrícula algo
  torcidas, plaza de mercado con campanario, mansión amurallada, campos, corrales con establo, molinos y aserradero.
  Cuatro guardias en las puertas.
- **Archivos:** `scripts/world/south_village.gd` (rehecho), `scripts/npc/gate_forces.gd`.
- **Cómo se probó:** fotos sin bruma; el juego corre sin errores; `quest_check.gd` pasa. Sin jugar.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** modelos y animales en G23 (los pasa Gabi); ronda 2.

### 2026-11-10 · G6 · Aldeas del Camino Sur · Gabi
- **Rama:** `gabi/g6-aldeas-sur` (borrada) · **Merge:** `6b645d0` · **Estado:** 🧪 falta revisar (ronda 2)
- **Qué se hizo:** una aldea skaa a los dos lados del camino de la Puerta Sur, centrada en (-20, 715): 22 chozas
  desparramadas (casi todas bajas), plaza con pozo, fogata y caldero, molino, establo, herrería, cuatro campos
  cercados con heno, torre de guardia en la entrada norte y cuadrillas skaa trabajando. Sin árboles ni lomas encima.
  El lugar `camino_sur` de la historia queda listo. También se puso al día `quest_check.gd`, que la G5 había dejado
  vieja (el taller y los corrales cambiaron).
- **Archivos:** `scripts/world/south_village.gd` (nuevo), `scripts/main.gd`, `scripts/world/exterior.gd`,
  `scripts/npc/skaa_crews.gd`, `scripts/story/story.gd`, `tools/story/quest_check.gd`.
- **Cómo se probó:** fotos sin bruma (desde arriba, en diagonal, por el camino y en la plaza); el juego corre sin
  errores; `quest_check.gd` y `tramo_check.gd` pasan. Sin jugar.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** ronda 2; modelos propios en G23; la misión "aldea" (Acto 2) llega con su acto.

### 2026-11-10 · G5 · Primer tramo jugable · Gabi
- **Rama:** `gabi/g5-primer-tramo` (borrada) · **Merge:** `35d8ae7` · **Estado:** 🧪 falta revisar (ronda 1)
- **Qué se hizo:** lo jugable de adentro de las misiones (`Mission`, `scripts/story/missions/`). Tejados: ruta de techo
  en techo (sale de los techos reales) con tres de la patrulla detrás. Foso: despertás en el fondo y subís hasta la
  entrada; el preso herido te sigue si lo ayudás (salvar o dejar). Taller: Clubs explica y se gasta el primer punto
  con la progresión de hoy. Las tres secundarias: corrales (pagar, pelear con el capataz y cuatro guardias, o no
  meterse), contrabando (tres cajas sin que te vean) y mensajero (seis espectros). Caer reinicia la misión. Pegarle
  a un guardia ya no pone en guerra a todos los de la ciudad: solo a los de 60 m.
- **Archivos:** `scripts/story/mission.gd` y `scripts/story/missions/` (nuevos), `quest_log.gd`, `dialogues.gd`,
  `quest_tracker.gd`, `scripts/ui/dialogue_box.gd`, `scripts/npc/champion.gd` (cambio puntual).
- **Cómo se probó:** `tools/story/tramo_check.gd` recorre el tramo y pasa; las pruebas ya no tocan la progresión
  guardada (antes, matar enemigos en una prueba sumaba experiencia de verdad). Sin jugar.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** ronda de revisión 1. El primer punto del taller cambia cuando Lucho termine L1-L6.

### 2026-11-10 · G4 · Misiones con los NPC del mapa · Gabi
- **Rama:** `gabi/g4-npc-misiones` (borrada) · **Merge:** `0496a62` · **Estado:** 🧪 falta revisar (ronda 1)
- **Qué se hizo:** las misiones del Acto 1 salen de la historia (`Story.QUESTS`) con sus pasos: ir al lugar y volver
  con quien la dio, que pregunta qué pasó y ahí se elige el final (con sus consecuencias). Las tres primeras
  (tejados, foso, afueras) arrancan solas y se cierran con una narración al llegar; el guardián del bosque, al
  acercarse. Conversaciones escritas a mano para Sazed, Clubs (también da la de Spook), Ham, Breeze, Tesa, Dockson
  y Tindwyl. Bajar a las salas del sótano cumple el paso de los maestros. Se fueron las misiones de prueba.
- **Archivos:** `scripts/story/` (quest_log, dialogues, quest_tracker, story), `scripts/training/training_room.gd`,
  `tools/story/quest_check.gd`.
- **Cómo se probó:** `quest_check.gd` recorre el Acto 1 entero y pasa; el juego corre sin errores. Sin jugar.
- **Conflictos:** ninguno.
- **Pendiente o pedidos:** lo jugable de adentro de cada misión es de G5. Ronda de revisión 1. Las partidas viejas
  arrancan de nuevo desde "Sobre los tejados".

### 2026-11-10 · G3 · Espectro de la bruma · Gabi
- **Rama:** `gabi/g3-espectro-bruma` (borrada) · **Merge:** `50d9b37` · **Estado:** 🧪 falta revisar (ronda 1)
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
- **Rama:** `gabi/g2-foso-ceniza` (borrada) · **Merge:** `6e9db37` · **Estado:** 🧪 falta revisar (ronda 1)
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
