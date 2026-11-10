# Tareas: Lucho y Gabi

Quién hace qué de acá en adelante. Para empezar o terminar una tarea, pedirle a Claude "empiezo la L3" o "terminé
la L3": la skill `tarea` (`.claude/skills/tarea/SKILL.md`) crea la rama, la mergea a develop, la borra y anota todo acá
y en `docs/REGISTRO.md`.

**Estados:** `- [ ]` pendiente · `- [ ] ⏸️` espera a otra tarea (dice cuál) · `- [ ] 🔄` en curso (con quién, rama y fecha) · `- [x] 🧪` en develop, falta revisar
(anotada en la [ronda de revisión](#ronda-de-revisión) abierta) · `- [x] ✅` verificada: revisada y aprobada (con fecha,
rama y merge).

## En curso

| Quién | Tarea | Rama | Desde |
|---|---|---|---|
| Lucho | — | — | — |
| Gabi | — | — | — |

## Cómo trabajamos

- **Lucho:** poderes, árboles de habilidades (alomancia y feruquimia), progresión y red.
- **Gabi:** escenarios, NPC, historia y misiones, modelos y animaciones.
- **Ramas:** cada tarea va en su propia rama que sale de `develop`: `lucho/<tarea>` o `gabi/<tarea>` (por ejemplo
  `lucho/progresion-datos`). Al terminar y probarla, se mergea a `develop`. Antes de empezar una tarea, actualizar
  `develop`.
- **Archivos compartidos** (`player.gd`, `model_rig.gd`, `humanoid_rig.gd`, `npc.gd`, `metal_bar.gd`): solo cambios
  puntuales, nunca reescribir. Ver `CLAUDE.md`.
- **Animaciones de poderes:** Lucho programa el poder con un clip provisorio en `HeroClips.SKILLS` y lo anota en
  [Pedidos de animación](#pedidos-de-animación). Gabi elige el clip real y tacha el pedido.
- Todo lo que hay que generar (personajes, gente, animales, objetos), en una sola lista: `docs/GENERAR.md`.
- Las tareas de modelos (P…) y de Gabi (Y…) tienen el detalle en `docs/PERSONAJES.md`; los actos, en
  `docs/HISTORIA_FLUJO.md`; el cambio de progresión, en `docs/PLAN_PROGRESION.md`.

## Lucho

### 1. Puntos en poderes (ver `docs/PLAN_PROGRESION.md`)

- [ ] **L1. Datos.** `skill_levels`, puntos (3 al inicio, 100 en el nivel 100), nivel del metal calculado,
  requisitos (todos los padres con 1 punto), inicio recomendado, guardado, `LAYOUTS` movido a `SkillTree`.
  Rama `lucho/progresion-datos`. Listo cuando pasa `tools/anim_check/progression_check.gd`.
- [ ] **L2. Poderes y metal.** Cada poder escala con sus puntos (`equiv_level`); el metal escala consumo y reserva
  con `METAL_SCALING`. Tooltips y textos. Listo cuando la Ráfaga 1 y 5 se ven distintas y el acero con 10 puntos
  dura más.
- [ ] **L3. Ventana K, lista.** "+" y "−" por poder, `0/5`, motivo cuando no se puede, nivel del metal calculado.
- [ ] **L4. Ventana K, árbol.** Pips, clic para subir y bajar, líneas por requisito.
- [ ] **L5. Trucos y sala.** Menú Esc (todo al máximo, inicio recomendado), sala de poderes (Ctrl+F8), pruebas
  `aim_check` y `aim_pitch_check`.
- [ ] **L6. Lugar para la feruquimia.** Campo `tree` en `SKILLS`, pestaña Alomancia | Feruquimia en K, puntos
  compartidos.
- ⚠️ **Al cerrar L1-L6, avisar a Gabi:** la misión del taller (G5) usa la progresión vieja para "gastar el primer
  punto"; se adapta en G22.

### 2. Metales que faltan (después de L1-L6)

Cada uno: diseño de su rama en `docs/arbol-de-habilidades.md` (partiendo de lo que ya está escrito ahí), poderes
en `SKILLS` y `LAYOUTS`, y pedido de animación para cada activa. Al terminar, ese metal deja de subirse directo
("Otros metales").

- [ ] **L7. Cinc.** (enardecer)
- [ ] **L8. Latón.** (aplacar)
- [ ] **L9. Cobre.** (ocultarse)
- [ ] **L10. Bronce.** (detectar)
- [ ] **L11. Atium.** (ver el futuro)
- [ ] **L12. Sacar "Otros metales"** y `direct_levels` cuando L7-L11 estén.

### 3. Feruquimia básica

- [ ] **L13. Diseño.** Qué guarda y qué gasta cada metal (mentes de metal), qué se ve en pantalla y cómo se
  recarga. Cualquier personaje puede usarla, con los mismos puntos que la alomancia. Va en
  `docs/arbol-de-feruquimia.md`; se revisa con Gabi antes de programar.
- [ ] **L14. Feruquimia: primeros metales** (los que salgan de L13).
- [ ] **L15. Feruquimia: el resto de los metales.**

### 4. Combinados

- [ ] **L16. Combinados de alomancia** (dos metales, escalones 1-3). Incluye **Y19, aterrizaje de héroe** (peltre +
  empuje de acero): clip `Dive_Down_and_Land_2`, tramo del 18 % al 65 %.
- [ ] **L17. Combinados de feruquimia.**
- [ ] **L18. Combinados de alomancia con feruquimia, y de tres o más metales.** Diseño antes de programar.

### 5. Después

- [ ] **L19. Red con la progresión nueva** (sección 6 del plan).
- [ ] **L20. Y16.** Los efectos de onda y bruma de los poderes en Lord Legislador, koloss, obligadores e inquisidores.
- [ ] **L21. Y8 e Y9.** Medir cuatro jugadores en red en Luthadel, caminando y peleando juntos.

## Gabi

### 0. Base

- [x] ✅ **G0.** Probar a Vin 5 minutos (vuelo, cinturón, guardia de puños, Casa skaa 6, lo que dejó la sesión de
  correcciones). Si está bien, commitear todo y subir a `develop` para que Lucho arranque desde ahí.
  — *verificada 2026-11-09, rama `escenarios-y-jugabilidad`, commit `d9bba6a`*

### 1. Historia jugable (primera meta: el tramo del Acto 1)

- [x] ✅ **G1. Y10.** Conversaciones, cuaderno, marcas del mapa y guardado en tres partidas.
  — *verificada 2026-11-09, rama `gabi/g1-dialogos-guardado` (borrada), merge `995558a`*
- [x] 🧪 **G2. Y5.** Foso de ceniza.
  — *en develop 2026-11-10, rama `gabi/g2-foso-ceniza` (borrada), merge `6e9db37`; falta revisar (ronda 1)*
- [x] 🧪 **G3. P5.** Espectro de la bruma (modelo y clips propios).
  — *en develop 2026-11-10, rama `gabi/g3-espectro-bruma` (borrada), merge `50d9b37`; falta revisar (ronda 1)*
- [x] 🧪 **G4. Y18.** Que las misiones usen a los NPC que ya están en el mapa.
  — *en develop 2026-11-10, rama `gabi/g4-npc-misiones` (borrada), merge `0496a62`; falta revisar (ronda 1)*
- [x] 🧪 **G5. Y11.** Primer tramo jugable: principales 1 y 2 y una secundaria con consecuencia. Necesita G1-G4.
  — *en develop 2026-11-10, rama `gabi/g5-primer-tramo` (borrada), merge `35d8ae7`; falta revisar (ronda 1)*

### 2. Escenarios

- [x] 🧪 **G6. Y6.** Aldeas del Camino Sur.
  — *en develop 2026-11-10, rama `gabi/g6-aldeas-sur` (borrada), merges `6b645d0` y `3e41809` (pueblo grande); falta revisar (ronda 2)*
- [x] 🧪 **G7. Y7.** Campamento koloss.
  — *en develop 2026-11-10, rama `gabi/g7-campamento-koloss` (borrada), merge `fe077b8`; falta revisar (ronda 2)*
- [x] 🧪 **G8. Y12.** Sacar al Lord Legislador de la Puerta Oeste y dejar libre la moneda de combate.
  — *en develop 2026-11-10, rama `gabi/g8-puerta-oeste` (borrada), merge `71a7133`; falta revisar (ronda 2). La moneda
  queda libre con L1 de Lucho (el inicio recomendado le da un punto): ver "Cuando Lucho suba"*

### 3. Modelos (los generás en Meshy; yo los integro)

- [ ] **G9. P6.** Spook.
- [ ] **G10. P13 y P14.** Violento y Lanzamonedas.
- [ ] **G11. P18 y P19.** Inquisidor y Yomen.
- [ ] **G12. P25.** Nena skaa con textura.
- [ ] **G13. P16.** Rugido del koloss joven (opcional).

### 4. NPC y animación

- [ ] **G14. Y2.** Koloss jefe.
- [ ] **G15. Y3.** Kandra (después de G9).
- [ ] **G16. Y4.** Colores de capa para repetir personaje.
- [ ] **G17. Y13.** Golpes y poderes de Kelsier y Vin como aliados o rivales.
- [ ] **G18. Y14 / P24.** Clips de los 3 poderes del Lord Legislador.
- [ ] **G19.** Atender los [Pedidos de animación](#pedidos-de-animación) de Lucho.
- [ ] **G20. Modelos propios del foso de ceniza** (los generás en Meshy; hoy son piezas de Quaternius): andamios de
  madera para las paredes, grúa o polea con balde, carretilla de ceniza, jaula de presos, cadenas y grilletes, torre
  del capataz, empalizada de troncos y montañas de ceniza. Listo cuando reemplazan a los de `scripts/world/ash_pit.gd`.
- [ ] **G21. Revisar cómo se mueve el espectro de la bruma**, al terminar la historia: jugarlo contra uno y contra
  tres, ver si el shader alcanza (ondular, arrastrarse, lanzarse, derretirse) o si hace falta otra cosa, y medir los
  FPS con los seis cerca. Hoy no se jugó con teclado (decisión del 10/11). Ver `scripts/character/wraith_rig.gd`.
- [ ] **G23. Modelos propios de los pueblos** (los pasa Gabi; hoy son piezas de Quaternius): casas que no sean todas de
  Quaternius, mansión noble propia, muralla de pueblo, cultivos de ceniza para los campos, espantapájaros, secaderos,
  bebederos y **animales para los corrales** (vacas, ovejas, cerdos, gallinas, caballos: hoy los corrales están
  vacíos). Listo cuando reemplazan a los de `scripts/world/south_village.gd`.
- [ ] **G24. Modelos propios del campamento koloss** (los pasa Gabi; hoy: conos, cercas y rocas): tiendas de cuero y
  hueso, estacas afiladas para la empalizada, huesos y calaveras de verdad, estantes de carne, jaulas, y carros para
  traer koloss (el "Cart" de Quaternius es un carrito de mercado, por eso hoy hay pilas de cajones).
- [ ] **G25. Mucha más gente en la ciudad y los pueblos** (después de que Gabi pase los modelos de abajo): muchos más
  skaa caminando y trabajando, nobles paseando con su séquito (mayordomo, doncella, guardia), mercaderes en los
  puestos, y lo mismo en las Aldeas del Camino Sur (300 casas: tiene que verse lleno). Medir los FPS con la gente
  nueva (hoy los NPC tienen esqueleto y animación cada uno). Hoy hay pocos modelos: skaa adultos 2 (`Skaa`,
  `SkaaObrero`), chicos 2 (`NinoSkaa`, `NinaSkaa`) y nobles 1 (`GordoNoble`). **Modelos que faltan** (Meshy, riggeados
  con esqueleto de Mixamo como los demás; toman los clips de la biblioteca de Vin):
  - Skaa mujer adulta: `Gaunt skaa woman in her thirties, ragged brown dress and shawl, ash-stained, tired face, full body, T-pose, no weapons`
  - Skaa viejo: `Old skaa man, bent back, ragged gray clothes, bald with white stubble, ash-stained, full body, T-pose, no weapons`
  - Skaa vieja: `Old skaa woman, hunched, patched dark dress and headscarf, ash-stained, full body, T-pose, no weapons`
  - Skaa joven trabajador: `Skinny young skaa laborer, torn shirt and rolled trousers, soot on face, full body, T-pose, no weapons`
  - Noble dama: `Elegant noblewoman, layered ball gown with corset, styled hair, gloves, haughty expression, full body, T-pose`
  - Noble joven: `Young nobleman, tailored dark suit with cravat and vest, slicked hair, full body, T-pose, no weapons`
  - Mayordomo: `Stern middle-aged butler, black tailcoat, white gloves, gray side-parted hair, upright posture, full body, T-pose`
  - Doncella: `Young house maid, dark dress with white apron and cap, modest, full body, T-pose`
  - Mercader: `Portly merchant, long coat over vest, coin purse at belt, cap, shrewd smile, full body, T-pose, no weapons`
  - Cochero: `Coachman in long dark coat and wide hat, scarf, gloves, full body, T-pose, no weapons`
  Listo cuando la ciudad y la aldea se ven llenas de gente variada y los FPS aguantan.
- [ ] **G26. Carretas y caballos** (después de que Gabi pase los modelos): carretas de carga y carruajes de nobles que
  andan por las calles y los caminos (Puerta Sur ↔ aldea, Puerta Este ↔ campamento koloss), tirados por caballos, con
  cochero (G25). También caballos en los establos y corrales de la aldea. **Modelos que faltan:**
  - Caballo de tiro, con sus clips (quieto, caminar, trotar, tirar). Meshy no riggea cuadrúpedos con el esqueleto de
    Mixamo: hay que ver de dónde salen los clips (un modelo ya animado, o riggearlo aparte).
  - Carreta de carga: `Wooden cargo wagon with four spoked wheels, plank sides, canvas cover, medieval, no horse`
  - Carruaje noble: `Ornate black noble carriage with four wheels, gilded trim, small windows, lanterns, no horse`
  Listo cuando hay carretas y carruajes moviéndose por las calles y los caminos, con caballos que caminan al paso.
- [ ] ⏸️ **G22. Adaptar lo que depende de la progresión de Lucho** — *espera a L1-L6*. Hoy, con la progresión vieja:
  - el paso "Gastar un punto en el árbol (K)" de la misión del taller (`QuestLog.STEPS["el_taller"]`, chequeado en
    `QuestTracker` con `Progression.points_spent()` / `points_free()`): pasarlo a puntos por poder y "elegir estilo";
  - si no hay puntos libres, hoy el paso se da por hecho solo: con los 3 puntos del inicio eso ya no pasa;
  - lo que dice Clubs en `Dialogues.LINES["clubs"]["taller_explica"]` sobre los metales;
  - correr `tools/story/tramo_check.gd` (la parte del taller simula el gasto con `outcome["el_taller_spent"]`).
  Listo cuando la misión del taller termina gastando un punto de verdad en la K nueva.

## Ronda de revisión

Lo que entró a develop sin que nadie lo jugara. Se juega todo junto, se anota acá lo que no anda, se arregla, y recién
ahí cada tarea pasa a ✅. Para cerrar la ronda: "revisemos la ronda 1".

### Ronda 1 (abierta desde 2026-11-10)

- [ ] **G2. Foso de ceniza** (oeste de la ciudad, al sudoeste de la Puerta Oeste):
  - [ ] bajar las rampas caminando hasta el fondo, y saltar de terraza en terraza;
  - [ ] que la forma irregular, los picos, los espolones y las lomas se vean bien de cerca y de lejos;
  - [ ] la empalizada, las torres, las barracas y las fogatas en su lugar; nada flotando ni enterrado;
  - [ ] presos trabajando y soldados en su puesto; los FPS adentro del foso.
- [ ] **G3. Espectro de la bruma** (camino del oeste y borde del bosque):
  - [ ] pelear contra uno y contra tres: que se lea cuándo se lanza y se pueda esquivar;
  - [ ] que ondular, arrastrarse, lanzarse y derretirse se vean bien (si no, G21);
  - [ ] los FPS con los seis cerca y su bruma.
- [ ] **G4. Misiones del Acto 1** (partida nueva):
  - [ ] tejados, foso y afueras: arrancan solas, el marcador lleva y la narración se abre al llegar;
  - [ ] Sazed ofrece el taller; después Clubs, Ham, Breeze, Tesa, Dockson y Tindwyl ofrecen la suya;
  - [ ] cada conversación: ofrecer, preguntar, rechazar, el recordatorio y la vuelta con el final elegido;
  - [ ] bajar a la sala de combate y a la pista desde Esc → Ir a cumple el paso de Ham y de Clubs;
  - [ ] el cuaderno (J), la brújula y el mapa muestran bien lo que está en curso y quién ofrece qué;
  - [ ] cargar una partida vieja (la 1) no rompe nada.
- [ ] **G5. Primer tramo jugable** (partida nueva; las tres secundarias se ofrecen después del taller):
  - [ ] tejados: la ruta de columnas de luz va de techo en techo y se puede seguir saltando; la patrulla corre detrás;
  - [ ] foso: despertás en el fondo; el herido te sigue si le hablás; la patrulla de las terrazas te ve de cerca;
    subir con él o sin él da la narración que corresponde;
  - [ ] caer en una misión la reinicia (volvés a llegar al lugar y arranca de nuevo);
  - [ ] taller: Clubs explica, K abre el árbol y gastar un punto la termina (con la progresión de hoy);
  - [ ] corrales: el capataz con sus cuatro guardias; pagar 50, pelear hasta tumbarlos o no meterse, y Tesa reacciona
    a lo que pasó de verdad;
  - [ ] contrabando: tres cajas en la Dársena, en tierra; si un soldado te ve de cerca te ataca;
  - [ ] mensajero: seis espectros alrededor; recién sin espectros se puede hablar con él;
  - [ ] que la dificultad se sienta bien (vida de la patrulla, cuántos te atacan juntos).
- [ ] **Misiones en general (G1/G2):** el cartel de la plaza con E, el objetivo bajo la brújula y el marcador en pantalla.

### Ronda 2 (abierta desde 2026-11-10)

- [ ] **G6. Aldeas del Camino Sur** (saliendo por la Puerta Sur, unos 300 m por el camino). Pueblo grande: 300 casas
  (pedido del 10/11: chico 50, mediano 100, grande 300), amurallado, con mansión noble y granjas:
  - [ ] que se lea denso y vivo, no pobre: calles con dos filas de casas y el centro de las manzanas lleno;
  - [ ] la muralla: torres, entradas donde pasan el camino sur y el desvío al bosque, guardias en las puertas;
  - [ ] la mansión del noble (noreste): muralla blanca con torreones, casa señorial, torre, glorieta, estandartes;
  - [ ] la plaza de mercado (oeste del camino): pozo, campanario, puestos, fogata;
  - [ ] afuera: arrabales sobre los caminos, campos con caseríos, corrales con establo, molinos y aserradero;
  - [ ] la cuadrícula: ¿se nota demasiado? (las calles están algo corridas y torcidas);
  - [ ] nada flotando ni enterrado (casas en pendiente, cercas, pozo); los caminos sin casas encima;
  - [ ] los FPS adentro del pueblo y mirándolo de lejos (300 casas, con colisión).

- [ ] **G7. Campamento koloss** (saliendo por la Puerta Este, unos 300 m al noreste, al norte del camino):
  - [ ] que se lea como campamento koloss: tiendas en corros, fogatas, hoguera del centro, huesos, carga apilada;
  - [ ] la empalizada rota a tramos y la entrada desde el camino (el camino pasa por el borde sur, sin cerca encima);
  - [ ] los ocho koloss junto a las fogatas: ¿es mucho para quien pasa por el camino? (te atacan a 24 m);
  - [ ] nada flotando ni enterrado; los FPS adentro, con los koloss y las fogatas.

- [ ] **G8. Puerta Oeste:** saliendo por la Puerta Oeste no hay nadie esperando, y el mapa ya no marca al Lord.

### Cuando Lucho suba la progresión nueva (L1-L6)

Lo que hay que actualizar de este lado (G22) y volver a probar:
- [ ] taller (G5): el paso "Gastar un punto en el árbol (K)" pasa a puntos por poder y elegir estilo
  (`QuestLog.STEPS["el_taller"]`, `QuestTracker`, `Progression.points_spent()` / `points_free()`);
- [ ] lo que explica Clubs de los metales (`Dialogues.LINES["clubs"]["taller_explica"]`);
- [ ] maestros (G4): las misiones de Ham, Breeze, Clubs y Spook enseñan poderes; ver si conviene que terminen
  dando o sugiriendo un punto en su estilo;
- [ ] dificultad de las misiones (G5): vida y cantidad de la patrulla, el capataz y los espectros, contra un jugador
  con 3 puntos al inicio en vez de la progresión de hoy;
- [ ] experiencia que dan los enemigos de las misiones (`xp_reward` de Champion y MistWraith) contra la curva nueva;
- [ ] moneda de combate (G8): que una partida nueva la tenga lista en el clic derecho sin gastar nada (el inicio
  recomendado de `PLAN_PROGRESION.md` le da uno de los 3 puntos); hoy pide un punto en acero;
- [ ] correr `tools/story/quest_check.gd` y `tools/story/tramo_check.gd`.

## Pedidos de animación

Lucho agrega una fila por poder nuevo; Gabi la tacha al poner el clip.

| Poder | Clip provisorio | Qué tiene que verse | Hecho |
|---|---|---|---|
| | | | |
