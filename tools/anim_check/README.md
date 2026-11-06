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
| `hit_check.gd` | El jugador de verdad pega con cada arma y golpe del combo a civiles quietos alrededor (adelante a 0,8–2,2 m, en diagonal, al costado, atrás): a quién le saca vida. | — |

Para leer los resultados (Python, `pip install pillow`):

- `python tools/anim_check/saltos.py <log>`: transiciones y **saltos de pose** (un hueso que se mueve mucho más que
  en los cuadros vecinos: una mezcla cortada).
- `python tools/anim_check/hoja_tramos.py <carpeta> <salida.png> <arma> tramo1,tramo2 2`: una fila por tramo.
- `python tools/anim_check/hoja_cuadros.py <carpeta> <salida.png> <arma>_<tramo> 1 16`: un tramo grande.

Valores de referencia (Vin, 7/11/2026): quieto -2 cm de suela (es el tobillo, cuenta como apoyado); caminando
±1 cm y el pie apoyado patina 0,02 m/s; ninguna transición con saltos salvo la entrada al bloqueo (rápida a propósito).
