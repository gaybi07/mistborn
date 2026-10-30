# Base reproducible (Etapa 0)

Fecha del diagnóstico: 2026-10-29. Rama `main`, commit `c8d7610` ("Estado inicial del proyecto Mister").

## Versión de Godot

| Dato | Valor |
|---|---|
| Versión exacta | `4.7.2.stable.official.ed1daf0bf` |
| Ejecutable (equipo de Luciano) | `C:\Users\lucia\OneDrive\Escritorio\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` |
| Ejecutable de consola | `...\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` |

Nota: `Godot_v4.7.2-stable_win64.exe` es una **carpeta** (extracción del zip) que contiene los dos ejecutables.
`project.godot` declara `config/features=("4.7", "Forward Plus")`, motor de física Jolt, MSAA 3D x2.

El otro desarrollador debe confirmar que usa **exactamente** `4.7.2.stable.official.ed1daf0bf` (`godot --version`).
Esa casilla de aceptación sigue pendiente: aquí solo se pudo verificar un equipo.

## Cómo iniciar

Escena principal: `res://scenes/main.tscn` (Luthadel). Abrir el proyecto en el editor y pulsar F5, o:

```bash
"<GODOT_CONSOLE>" --path .
```

## Cómo entrar a la arena

- **F2**: cambia a `arena.tscn` desde cualquier escena (autoload `InputSetup`, `scripts/core/input_setup.gd`).
- **F1**: vuelve a la ciudad.
- En la arena se abre el menú de combates (**M**; Esc mirando). Los combates "Tú vs ..." te ponen como luchador; los demás son modo espectador.
- **R** repite el combate.
- Kredik Shaw: se entra por la puerta (portal) al pie de la torre central de la ciudad; no hay tecla directa.
- Controles generales: WASD mover, Espacio saltar, Shift rodar/dash, 1-4 y Z X C V B metales, clic izq./der. tirar/empujar, E atacar, Q moneda, Tab rueda de metales, F3/F4/F5 hora/clima/niebla. Lista completa en `scripts/ui/pause_menu.gd`.

## Comandos reproducibles

`GODOT_CONSOLE` = ruta del ejecutable `_console.exe`. Ejecutar desde la raíz del proyecto.

```bash
# Versión
"$GODOT_CONSOLE" --version

# Carga de cada escena sin ventana, 120 fotogramas
"$GODOT_CONSOLE" --headless --path . --quit-after 120 res://scenes/main.tscn
"$GODOT_CONSOLE" --headless --path . --quit-after 120 res://scenes/arena.tscn
"$GODOT_CONSOLE" --headless --path . --quit-after 120 res://scenes/kredik_shaw.tscn

# Análisis de sintaxis de los 53 scripts
for f in $(find scripts -name "*.gd"); do
  "$GODOT_CONSOLE" --headless --path . --check-only --script "res://$f"
done
```

No se usó `--import`/`--editor` a propósito: reescriben los `.import`.

## Resultados

| Escena | Comando | Código de salida | Salida del motor |
|---|---|---|---|
| `main.tscn` | `--headless --quit-after 120` | 0 | Solo el banner y `Luthadel: 287 casas skaa` (mensaje informativo del propio juego). Sin errores ni advertencias. |
| `arena.tscn` | idem | 0 | Solo el banner. Sin errores ni advertencias. |
| `kredik_shaw.tscn` | idem | 0 | Solo el banner. Sin errores ni advertencias. |
| 53 scripts `.gd` | `--check-only --script` | 0 en todos | 0 scripts con errores o advertencias. |

Conclusión: las tres escenas cargan y corren 120 fotogramas sin errores de script.

## Errores, advertencias y limitaciones conocidas

- Ninguna advertencia ni error propio del proyecto en las pruebas anteriores.
- **Limitación de la verificación:** es headless (sin renderizado). No se probó visualmente, ni el cambio F1/F2 con teclado, ni el inicio de un combate concreto en la arena ni el portal a Kredik Shaw. La carga de la arena prueba solo el estado inicial (menú + cámara espectador); una prueba scriptada para arrancar el combate 7 ("Tú vs Violento") no terminó (se colgó hasta el timeout de 120 s y se descartó; **no concluyente**, no es evidencia de un fallo del juego). Sigue pendiente la comprobación manual "la arena funciona en modo individual".
- Si Godot se cierra por la fuerza (timeout) imprime ruido de salida (`Unreferenced static string`, RIDs filtrados de NavMesh); eso proviene de matar el proceso, no del proyecto.
- `.godot/` está en `.gitignore` (caché regenerable por cada equipo). Los `.exe` y `.pck` también.
- Reimportar en otro equipo puede reescribir `.import` (ver abajo).

## Estado inicial de git

Rama `main`, un solo commit. `git status` al comenzar:

- **18 archivos `.import` modificados** (preexistentes, automáticos; no son trabajo de esta etapa):
  - `assets/kaykit/characters/`: Barbarian, Knight, Mage, Rogue_Hooded, Rogue (`*_texture.png.import`)
  - `assets/kaykit/items/`: `knight_texture`, `rogue_texture`
  - `assets/quaternius/characters/`: Cleric (2), Monk, Ranger (2), Rogue (2), Warrior (2), Wizard (2)
- El cambio es de formato de importación: pasan de `path=...ctex` / `vram_texture=false` a `path.s3tc=...s3tc.ctex` / `vram_texture=true` (compresión VRAM S3TC/BPTC). Es un efecto de abrir el proyecto en Godot en un equipo de escritorio con otra configuración de importación.
- `docs/PLAN_MULTIJUGADOR.md` sin seguimiento (preexistente).
- Con esta etapa se agrega `docs/BASELINE.md`.

Verificación: la huella SHA-256 de `git diff` y de `git status --short` fue idéntica antes y después de ejecutar todos los comandos de Godot, es decir, las validaciones no tocaron ningún `.import`.

Recomendación para la Etapa 1 (no aplicada): decidir en un commit aparte si esos 18 `.import` se versionan o se descartan, para que ambos desarrolladores partan del mismo estado.
