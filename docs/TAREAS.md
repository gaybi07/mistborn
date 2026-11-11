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
| Lucho | L8 a L12 (ramas apiladas: latón, cobre, bronce, atium, sala de pruebas) | `lucho/l8-laton` → … → `lucho/l11-atium` → `lucho/l12-sala-pruebas` | 2026-11-11 |
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

- [x] ✅ **L1. Datos.** `skill_levels`, puntos (3 al inicio, 100 en el nivel 100), nivel del metal calculado,
  requisitos (todos los padres con 1 punto), inicio recomendado, guardado, `LAYOUTS` movido a `SkillTree`.
  — *verificada 2026-11-10, rama `lucho/l1-progresion-datos` (borrada), merge `a176d5c`*
- [x] ✅ **L2. Poderes y metal.** Cada poder escala con sus puntos (`equiv_level`); el metal escala consumo y reserva
  con `METAL_SCALING`. Tooltips y textos.
  — *verificada 2026-11-10, rama `lucho/l2-poderes-metal` (borrada), merge `bc25a1b`*
- [x] ✅ **L3. Ventana K, lista.** "+" y "−" por poder, `0/5`, motivo cuando no se puede, nivel del metal calculado.
  — *verificada 2026-11-10, rama `lucho/l3-ventana-lista` (borrada), merge `c4a011c`*
- [x] ✅ **L4. Ventana K, árbol.** Pips, clic para subir y bajar, líneas por requisito.
  — *verificada 2026-11-10, rama `lucho/l4-ventana-arbol` (borrada), merge `f5136dc`*
- [x] ✅ **L5. Trucos y sala.** Menú Esc (todo al máximo, inicio recomendado), sala de poderes (Ctrl+F8), pruebas
  `aim_check` y `aim_pitch_check`. — *verificada 2026-11-10, rama `lucho/l5-trucos-sala` (borrada), merge `9b8f46b`*
- [x] ✅ **L6. Lugar para la feruquimia.** Campo `tree` en `SKILLS`, pestaña Alomancia | Feruquimia en K, puntos
  compartidos. — *verificada 2026-11-10, rama `lucho/l6-feruquimia-lugar` (borrada), merge `cbd106e`*
- ✅ Lo que dependía de L1-L5 del lado de Gabi ya se adaptó en G22 (taller, Clubs, moneda, experiencia).
  **Aviso a Gabi (2026-11-10):** L1-L6 ya están en develop (L6 solo agrega la pestaña de feruquimia y no cambia nada
  para G22), que ya se puede hacer. Hoy, con los 3 puntos del inicio ya gastados, el paso del taller se da por hecho solo.
  Para gastar un punto: `Progression.raise_skill(id)` / `can_raise_skill(id)`; los puntos libres siguen en
  `points_free()`.

### 2. Metales que faltan (después de L1-L6)

Cada uno: diseño de su rama en `docs/arbol-de-habilidades.md` (partiendo de lo que ya está escrito ahí), poderes
en `SKILLS` y `LAYOUTS`, y pedido de animación para cada activa. Al terminar, ese metal deja de subirse directo
("Otros metales").

- [x] ✅ **L7. Cinc.** (enardecer) — *verificada 2026-11-10, rama `lucho/l7-cinc` (borrada), merge `9ca9394`*
- [ ] 🔄 **L8. Latón.** (aplacar) — *en curso: Lucho, rama `lucho/l8-laton`, desde 2026-11-11*
- [ ] 🔄 **L9. Cobre.** (ocultarse) — *en curso: Lucho, rama `lucho/l9-cobre` (sale de la de L8), desde 2026-11-11*
- [ ] 🔄 **L10. Bronce.** (detectar) — *en curso: Lucho, rama `lucho/l10-bronce` (sale de la de L9), desde 2026-11-11*
- [ ] 🔄 **L11. Atium.** (ver el futuro) — *en curso: Lucho, rama `lucho/l11-atium` (sale de la de L10), desde 2026-11-11*
- [ ] 🔄 **L12. Sacar "Otros metales"** y `direct_levels` cuando L7-L11 estén. Además (pedido de Lucho, 10/11), **la sala
  de poderes pasa a ser una sala de pruebas de verdad** (hoy Ctrl+F8, `scripts/training/skill_room.gd`: piso pelado y
  todo al máximo):
  - un **menú interactivo** al entrar (y reabrible adentro) para elegir qué probar: "Probar Acero", "Probar Hierro",
    "Probar Peltre", "Probar Estaño", "Probar Cinc", "Probar Latón", "Probar Cobre", "Probar Bronce", "Probar Atium";
  - al elegir un metal, **el escenario se arma para sus poderes**: lo que cada uno necesita para usarse y verse. Por
    ejemplo, metales sueltos, farolas y rejas para acero y hierro; muñecos y paredes para golpes y onda de choque en
    peltre; NPC detrás de paredes para el estaño; y para cinc y latón, **NPC de cada tipo** (ciudadanos, guardias,
    koloss, alománticos, uno con cobre) para provocar, asustar, domar o calmar;
  - **spawnea los NPC** que hacen falta, con un botón para volver a armar la prueba (reaparecen los que cayeron);
  - ese metal y sus poderes al máximo y ya puestos en las ranuras, para probar sin pasar por K;
  - al salir, los puntos y las ranuras vuelven a como estaban (como hoy).
  Listo cuando desde la sala se puede elegir cada metal y probar todos sus poderes sin salir, y los dos `aim_check`
  siguen pasando. — *en curso: Lucho, rama `lucho/l12-sala-pruebas` (sale de la de L11), desde 2026-11-11*

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
- [ ] **G30. Conversaciones sin frenar el juego** (pedido de Lucho, 10/11): hoy el cartel de diálogo
  (`scripts/ui/dialogue_box.gd`) pone `player.ui_open = true` y suelta el cursor, así que el personaje se congela y,
  si te persigue alguien o estás peleando, no podés seguir jugando mientras elegís. Lo acordado:
  - mientras el cartel está abierto, **caminás, mirás, saltás, rodás y peleás**: no se toca `ui_open` y el cursor
    queda capturado;
  - **1–4** eligen la opción (ya están numeradas en pantalla); mientras hay una conversación abierta, las ranuras en
    1–4 se pausan (5, Q, E, F, Z, X, C y V siguen andando);
  - **Enter** elige la primera opción o "(Seguir)";
  - **Tab** (mantener) libera el cursor para elegir con clic, como ya hace con los metales;
  - **Esc** cierra, como hoy;
  - el cartel **se cierra solo** si te alejás a más de **8 m** del NPC.
  Revisar que la tecla de ranura (`Player._skill_key` / `Progression.slot_for_key`) no dispare un poder con 1–4 mientras
  hablás, y que Esc cierre el cartel sin abrir también el menú de pausa.
  Listo cuando se puede hablar con un NPC de misión mientras te persigue la patrulla, elegir con 1–4 o Enter sin
  frenarte, y alejarse cierra la conversación.

### 2. Escenarios

- [x] 🧪 **G6. Y6.** Aldeas del Camino Sur.
  — *en develop 2026-11-10, rama `gabi/g6-aldeas-sur` (borrada), merges `6b645d0` y `3e41809` (pueblo grande); falta revisar (ronda 2)*
- [x] 🧪 **G7. Y7.** Campamento koloss.
  — *en develop 2026-11-10, rama `gabi/g7-campamento-koloss` (borrada), merge `fe077b8`; falta revisar (ronda 2)*
- [x] 🧪 **G8. Y12.** Sacar al Lord Legislador de la Puerta Oeste y dejar libre la moneda de combate.
  — *en develop 2026-11-10, rama `gabi/g8-puerta-oeste` (borrada), merge `71a7133`; falta revisar (ronda 2). La moneda
  queda libre con L1 de Lucho (el inicio recomendado le da un punto): ver "Cuando Lucho suba"*

### 3. Modelos (los generás en Meshy; yo los integro)

- [x] 🧪 **G9. P6.** Spook: en el taller, da la misión de la pista (antes la daba Clubs).
  — *en develop 2026-11-10, rama `gabi/g9-spook` (borrada), merge `ba9a003`; falta revisar (ronda 2)*
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
- [x] 🧪 **G24. Modelos propios del campamento koloss** (los pasó Gabi, 13 de Meshy): torre, refugio, trono, jaula,
  tambor, efigies, tótem, barricada, cajón, barril y tres espadones, ya en el campamento.
  — *en develop 2026-11-10, rama `gabi/g24-campamento-koloss` (borrada), merge `cd31c50`; falta revisar (ronda 2)*
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
- [x] 🧪 **G27. Piezas propias de Luthadel y plazas góticas** (generadas por Claude en Blender, con texturas): casas,
  caserón y torre góticos, fuentes, cadalso, puestos de lona, carreta; Plaza Central y Mercado rearmados; paleta de
  día gris con el horizonte rojo; hollín en las casas comunes.
  — *en develop 2026-11-10, rama `gabi/g27-casas-plaza` (borrada), merge `53ea3f6`; falta revisar (ronda 2)*
- [x] 🧪 **G28. Casas modulares** (generadas en Blender con las texturas de G27): 24 casas de barrios buenos y 24 skaa,
  combinando módulos, puestas en sus barrios y en el pueblo del Camino Sur.
  — *en develop 2026-11-10, rama `gabi/g28-casas-modulares` (borrada), merge `fffd775`; falta revisar (ronda 2)*
- [x] 🧪 **G29. Muralla de Luthadel, rehecha** (pedido de Gabi, 10/11): piezas propias con textura de sillar grande
  (seis tramos de distinta altura y estado, tres torres y un portón con dos torres) y 12 puertas: las tres de la
  historia y nueve con nombre de metal, cada una con camino corto, dos guardias y calle hacia adentro.
  — *en develop 2026-11-10, rama `gabi/g29-muralla` (borrada), merge `3a02a7b`; falta revisar (ronda 2)*
- [x] 🧪 **G22. Adaptar lo que depende de la progresión de Lucho** (L1-L5): el taller da un punto libre y termina al
  gastarlo, Clubs habla de lo que ya sabés, la moneda de combate viene lista, y los enemigos de las misiones dan
  menos experiencia (patrulla 35, espectro 40).
  — *en develop 2026-11-10, rama `gabi/g22-progresion-nueva` (borrada), merge `04527b5`; falta revisar (ronda 2)*
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

- [ ] **G24. Campamento koloss con los modelos de Meshy**: el trono, los tambores y los tótems con brasas en el centro;
  refugios alrededor de las fogatas; barricadas como empalizada; que nada flote ni se hunda (los tambores están
  acostados, como vinieron); los FPS adentro (unos 160 modelos de 1200 a 4900 triángulos).
- [ ] **G7. Campamento koloss** (saliendo por la Puerta Este, unos 300 m al noreste, al norte del camino):
  - [ ] que se lea como campamento koloss: tiendas en corros, fogatas, hoguera del centro, huesos, carga apilada;
  - [ ] la empalizada rota a tramos y la entrada desde el camino (el camino pasa por el borde sur, sin cerca encima);
  - [ ] los ocho koloss junto a las fogatas: ¿es mucho para quien pasa por el camino? (te atacan a 24 m);
  - [ ] nada flotando ni enterrado; los FPS adentro, con los koloss y las fogatas.

- [ ] **G8. Puerta Oeste:** saliendo por la Puerta Oeste no hay nadie esperando, y el mapa ya no marca al Lord.

- [ ] **G27. Plazas góticas y piezas propias** (Plaza Central, donde arrancás, y Mercado, al noreste):
  - [ ] que el clima se parezca a las fotos de referencia: piedra oscura, lonas grises, cielo plomo con rojo;
  - [ ] la paleta de día nueva en toda la ciudad (antes naranja): ¿queda bien lejos de las plazas? ¿y de noche?
  - [ ] el hollín sobre las casas comunes: ¿demasiado oscuras?
  - [ ] subir a la grada de la fuente, caer al agua, subir al cadalso por la escalera (colisiones propias);
  - [ ] los frentes góticos de la plaza: que no tapen calles ni pisen otras casas;
  - [ ] las casas comunes cambiaron de lugar en toda la ciudad (por los terrenos reservados): recorrer los barrios y
    ver que no haya casas sobre calles, NPC adentro de una casa o puestos de misión tapados;
  - [ ] los cajones de metal, monedas y frascos de la plaza siguen a mano; los FPS con las texturas nuevas.

- [ ] **G28. Casas modulares** (barrios Noble, Mercantil, mercaderes, Plaza Central, Laderas y Distrito Skaa):
  - [ ] que las casas se vean parecidas pero distintas, sin repetirse a la vista;
  - [ ] que las skaa se lean pobres y las buenas, de gente con plata;
  - [ ] nada flotando ni enterrado en las calles en pendiente; puertas que den a la calle;
  - [ ] la persecución de los tejados con los techos nuevos, más empinados (¿se puede correr por ellos?);
  - [ ] los FPS en los barrios densos (2411 casas, unos 900 triángulos cada una).

- [ ] **G9. Spook** (junto al taller): que se vea bien caminando y quieto (usa los clips de la biblioteca de Vin,
  a 1,7 m); hablarle con E, preguntarle por la venda, aceptar la pista, bajar por Esc → Ir a y volver a contarle.
- [ ] **G22. Taller con la progresión nueva** (partida nueva): Clubs te explica, te sube a nivel 4 con un punto libre,
  y la misión termina recién al gastarlo en la K; la moneda de combate lista en el clic derecho desde el principio;
  ¿cuántos niveles se suben en el Acto 1 con la experiencia nueva? (unos 6, según la cuenta).
- [ ] **G29. Muralla** (rodear la ciudad por afuera y entrar por varias puertas):
  - [ ] que se vea medieval e imperfecta: altos y bajos, almenas rotas, remiendos, contrafuertes, torres variadas;
  - [ ] las 12 puertas en el mapa con su nombre; cruzar caminando por cada portón y por la del Cinc y la del Latón,
    que están cerca una de otra;
  - [ ] los caminos cortos de las puertas nuevas y sus dos guardias (no deberían atacar si no les pegás);
  - [ ] el paso del río bajo la muralla con sus rejas, y la Puerta Este, que está a 25 m del río;
  - [ ] los árboles y troncos de afuera cambiaron de lugar (los caminos nuevos usan la misma semilla): que no tapen
    nada; los FPS mirando la muralla de lejos.

### Lo que dependía de la progresión de Lucho (hecho en G22)

L1-L5 ya están en develop. Lo de este lado quedó así (revisar en la ronda 2):
- [x] taller (G5): Clubs te entrena hasta tener un punto libre y la misión termina al gastarlo en la K
  (`QuestLog.advance`, `QuestTracker`); `tools/story/taller_check.gd` lo prueba con una partida nueva;
- [x] lo que explica Clubs: lo que ya sabés (acero, hierro, moneda) y lo que falta (peltre, estaño);
- [x] moneda de combate (G8): una partida nueva la trae lista en el clic derecho (`START_SKILLS` de L1);
- [x] experiencia de los enemigos de las misiones: patrulla 35 (antes heredaba los 220 del koloss), espectro 40;
- [x] `quest_check.gd` y `tramo_check.gd` pasan, y ya no tocan la progresión guardada;
- [ ] maestros (G4): ¿conviene que las misiones de Ham, Breeze y Clubs terminen sugiriendo un punto en su estilo?
  Quedó como estaba: decidirlo al jugar;
- [ ] dificultad de las misiones (G5) contra un jugador que arranca con 3 puntos: juzgarla al jugar la ronda;
- [ ] cuando Lucho cierre L6 (feruquimia): ver si el taller o Clubs tienen que nombrarla.

## Pedidos de animación

Lucho agrega una fila por poder nuevo; Gabi la tacha al poner el clip.

| Poder | Clip provisorio | Qué tiene que verse | Hecho |
|---|---|---|---|
| Ira (cinc, `zinc_fury`) | `hunter_mark` (señalar) | Señala al NPC con el brazo tenso y el puño cerrado, como azuzándolo; corto (~1 s) | |
| Pánico (cinc, `zinc_panic`) | `field` | Gesto brusco de espantar hacia adelante, como para asustar | |
| Avaricia (cinc, `zinc_greed`) | `play_throw` (tirar moneda) | Lanza una moneda en parábola hacia donde apunta, de costado y despreocupado | |
| Domar (cinc, `zinc_tame`) | `burn_focus` | Mano extendida hacia el NPC, palma abierta, invitándolo a seguirlo | |
| Tormenta de emociones (cinc, `zinc_storm`) | `fury` (rugido) | Abre los brazos y libera una onda en todas direcciones; más grande que Ira | |
| Calma (latón, `brass_calm`) | `clear_mind` | Palma abierta hacia el NPC, bajándola despacio, como pidiendo calma | |
| Desaliento (latón, `brass_dishearten`) | `field` | Gesto de desdén con la mano, hacia abajo y afuera | |
| Rendición (latón, `brass_yield`) | `burn_focus` | Mano extendida hacia el NPC, firme, pidiéndole que suelte el arma | |
| Sosegar multitud (latón, `brass_crowd`) | `field` | Los dos brazos bajan despacio en abanico hacia adelante | |
| Paz absoluta (latón, `brass_peace`) | `clear_mind` | Brazos abiertos, ojos cerrados, onda calma en todas direcciones | |
| Desvanecerse (cobre, `copper_vanish`) | `burn_focus` | Se encoge y se envuelve en humo, como fundiéndose con la bruma | |
| Nube compartida (cobre, `copper_shared`) | `field` | Abre los brazos como cubriendo a alguien al lado | |
| Fantasma (cobre, `copper_ghost`) | `burn_focus` | Cierra los ojos y baja los hombros; quieto, casi transparente | |
| Pulso perturbador (bronce, `bronze_disrupt`) | `field` | Golpe seco de las dos palmas hacia afuera, como rompiendo algo invisible | |
| Rastreo (bronce, `bronze_track`) | `extreme_senses` | Ojos cerrados, cabeza que gira despacio escuchando | |
| Contrapulso (bronce, `bronze_counter`) | `mass_yank` | Junta las manos y suelta una onda hacia todos lados | |
| Monedas guiadas (atium, `atium_guided`) | `coin_wave` | Abanico de monedas lanzado sin mirar, cada una hacia un lado distinto | |
| Momento eterno (atium, `atium_eternal`) | `burn_focus` | Inspira hondo y abre los ojos de golpe; el cuerpo se tensa listo para moverse | |
