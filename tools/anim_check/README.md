# Pruebas de animación

Todas usan a Vin (`Art.player_model = "vin"`) y no guardan nada en la configuración del jugador. Se corren con la
consola de Godot desde la carpeta del proyecto; después, `git checkout -- project.godot` (Godot lo toca al abrir).

```
G=/c/Users/gabih/Downloads/Godot/Godot_v4.7.2-stable_win64_console.exe
$G --path . -s tools/anim_check/<prueba>.gd -- <argumentos>
```

| Prueba | Qué mide | Argumentos |
|---|---|---|
| `combat_film.gd` | Filma a 30 fps cada arma (puños, dagas, espada, escudo) en guardia, caminar, agacharse, combo, aire, bloqueo y cada poder. Imprime la velocidad de cabeza, manos, pies y cadera por cuadro. | `<carpeta> [arma,...\|all] [tramo,...] ["estado=clip;..."]` |
| `trans_film.gd` | Transiciones: agacharse, guardia, caminar/correr/frenar, bloqueo, golpe, saltos, caídas, rodadas. | `<carpeta> [escenario,...]` |
| `feet_check.gd` | Con piso real: si los pies flotan o se hunden, cuánto patina el pie apoyado y si el cuerpo apoya al rodar. | `[caso,...]` |
| `strike_check.gd` | Dónde están el puño, la hoja o el pie en el cuadro del impacto de cada golpe del combo. | — |
| `clip_measure.gd` | Largo de cada clip, cuándo se mueve y el pico de velocidad de la mano (el golpe), para cortar y sincronizar. | `clip1,clip2,... [kit]` |
| `lord_check.gd` | El Lord Legislador tira cada poder contra Vin: vida que saca quieta o esquivando (`- all 7 esquivar`), fotos de arriba y saltos de pose con LORD_LOG=1. | `<carpeta|-> [poder,...|all] [dist] [esquivar]` |
| `champion_check.gd` | Los koloss, el inquisidor y el obligador tiran cada poder contra Vin: cuánto aviso hubo y la vida que sacan, quieta o esquivando. | `[kit,...|all] [esquivar]` |
| `aim_check.gd` | Tus poderes con zona: mantener para apuntar (zona azul) y soltar. | `<carpeta>` |
| `run_start_check.tscn` | En la sala de poderes con Vin: aprieta W desde quieta, velocidad real cada 0,1 s y cuándo llega a correr. Con `--headless`. | — |
| `run_jump_check.tscn` | En la sala de poderes con Vin, sin metales: corre con W y salta. Velocidad real antes, en el aire y al caer, y avance en 3 s contra correr sin saltar (saltar no debe frenar). Correr con `--headless`: con ventana, si pierde el foco se pausa. | — |
| `steel_jump_check.tscn` | En la sala de poderes con Vin y acero: W + Espacio. Anota la trayectoria, altura y avance, cuánto se aparta de una parábola, y un segundo salto enseguida (en recarga sale el común). Se corre como escena. | `[segundos con Espacio apretado]` |
| `slam_guard_check.tscn` | En la sala de poderes con Vin y sin enemigos: el Martillazo no deja la guardia de combate puesta después del clip. Se corre como escena. | — |
| `skill_burn_check.tscn` | En la sala de poderes con Vin: usa cada poder activo con los metales apagados y revisa que al terminar no quede ninguno encendido, y que un metal que ya quemabas siga encendido. Se corre como escena. | — |
| `aim_pitch_check.tscn` | En la sala de poderes con Vin: el humo de la lanza y de la ráfaga va del pecho a la línea de la mira (arriba y abajo), el de la embestida sale de los pies hacia la cámara y los aros (golpe al piso, tirón, campo) rodean los pies. Se corre como escena (`Godot --path . res://tools/anim_check/aim_pitch_check.tscn -- ...`), no con `-s`. | `<carpeta> [nivel de acero]` |
| `arm_measure.gd` | Brazos y torso de Vin cuadro a cuadro en un clip: codo, hacia dónde apunta, altura y mano respecto del pecho. | `clip[@res://donante.glb] [pasos]` |
| `skill_arm.gd` | Lo mismo, mientras hace un poder en el juego (capa de arriba sobre la guardia), con el momento en que suelta. | `<poder>` |
| `hit_check.gd` | El jugador de verdad pega con cada arma y golpe del combo a civiles quietos alrededor (adelante a 0,8–2,2 m, en diagonal, al costado, atrás): a quién le saca vida. | — |

Para leer los resultados (Python, `pip install pillow`):

- `python tools/anim_check/saltos.py <log>`: transiciones y **saltos de pose** (un hueso que se mueve mucho más que
  en los cuadros vecinos: una mezcla cortada).
- `python tools/anim_check/hoja_tramos.py <carpeta> <salida.png> <arma> tramo1,tramo2 2`: una fila por tramo.
- `python tools/anim_check/hoja_cuadros.py <carpeta> <salida.png> <arma>_<tramo> 1 16`: un tramo grande.

Valores de referencia (Vin, 7/11/2026): quieto -2 cm de suela (es el tobillo, cuenta como apoyado); caminando
±1 cm y el pie apoyado patina 0,02 m/s; ninguna transición con saltos salvo la entrada al bloqueo (rápida a propósito).
