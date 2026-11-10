# Tareas: Lucho y Gabi

Quién hace qué de acá en adelante. Para empezar o terminar una tarea, pedirle a Claude "empiezo la L3" o "terminé
la L3": la skill `tarea` (`.claude/skills/tarea/SKILL.md`) crea la rama, la mergea a develop, la borra y anota todo acá
y en `docs/REGISTRO.md`.

**Estados:** `- [ ]` pendiente · `- [ ] 🔄` en curso (con quién, rama y fecha) · `- [x] ✅` verificada (con fecha,
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

- [ ] **G1. Y10.** Conversaciones, cuaderno, marcas del mapa y guardado en tres partidas.
- [ ] **G2. Y5.** Foso de ceniza.
- [ ] **G3. P5.** Espectro de la bruma (modelo y clips propios).
- [ ] **G4. Y18.** Que las misiones usen a los NPC que ya están en el mapa.
- [ ] **G5. Y11.** Primer tramo jugable: principales 1 y 2 y una secundaria con consecuencia. Necesita G1-G4.

### 2. Escenarios

- [ ] **G6. Y6.** Aldeas del Camino Sur.
- [ ] **G7. Y7.** Campamento koloss.
- [ ] **G8. Y12.** Sacar al Lord Legislador de la Puerta Oeste y dejar libre la moneda de combate.

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

## Pedidos de animación

Lucho agrega una fila por poder nuevo; Gabi la tacha al poner el clip.

| Poder | Clip provisorio | Qué tiene que verse | Hecho |
|---|---|---|---|
| | | | |
