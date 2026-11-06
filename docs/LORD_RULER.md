# Lord Legislador: poderes y avisos

Hecho en `scripts/npc/lord_powers.gd` (los poderes), `scripts/fx/telegraph.gd` + `shaders/telegraph.gdshader` (los avisos)
y `Champion` (lo conecta). Se prueba con `tools/anim_check/lord_check.gd` (cada poder contra Vin, quieta o esquivando).
Usa todos los poderes de Vin (alomancia) más feruquimia, que Vin no tiene.
Los golpes comunes (combos con espada) **no avisan**: se leen en la animación y se esquivan.

## Cómo avisa (el mismo idioma para todo)

| Señal | Qué te dice |
|---|---|
| **Rojo en el piso** que se va llenando | Ahí va a pegar. Cuando se llena, pega. Mínimo 0,7 s de aviso; los poderes grandes, 1–1,5 s. |
| Forma del rojo | **Círculo**: alrededor de él o en un punto. **Anillo**: se salva el centro o el afuera. **Cono**: adelante de él. **Franja/rayo**: una línea recta (salí de costado). |
| **Línea roja fina** de él hacia vos | Te está apuntando un proyectil o un tirón. Salí de la línea. |
| **Destello blanco** | El momento exacto del golpe. |
| **Aura del color del metal** en él | Qué metal quema: acero azul, hierro celeste, peltre naranja, estaño crema, emociones violeta, atium dorado, feruquimia verde. Sin daño: es información. |
| **Nombre del poder** sobre él | Igual que ahora. |
| **Sonido** de aviso por tipo, y una **flecha** en el borde de la pantalla | Si el ataque viene de fuera de cámara. |

Todo con bruma y ondas (como `AirFx`), nada de sprites rígidos. La forma roja es la misma que usa el cálculo de daño:
lo que ves es exactamente lo que pega. Opción en ajustes para bajar destellos y temblor de cámara.

## Fases

1. **Más del 60 % de vida**: acero y hierro.
2. **60–30 %**: suma peltre, estaño y emociones.
3. **Menos del 30 %**: suma feruquimia y atium; encadena poderes más seguido.

## Poderes de alomancia (los mismos de Vin)

| # | Poder | Qué hace | Aviso |
|---|---|---|---|
| 1 | Empuje de acero | Te empuja lejos, con daño | **Cono** rojo adelante, 12 m |
| 2 | Moneda de combate | Ráfaga de 3 monedas hacia vos | **Línea** roja fina 0,7 s antes de cada tanda |
| 3 | Ráfaga de monedas | Abanico de monedas | **Cono** rojo ancho, rayado |
| 4 | Escudo de monedas | Monedas girando alrededor: frena tus monedas. Al rato revienta | Anillo de monedas (sin rojo). Antes de reventar: **círculo** rojo 5 m alrededor de él |
| 5 | Campo magnético | Cúpula de 8 m que desvía tus monedas y armas de metal | Borde **azul** (no hace daño, no es rojo) |
| 6 | Lanza de acero | Rayo de acero en línea recta, muy largo | **Franja** roja angosta de 30 m, 1,2 s antes |
| 7 | Tirón de hierro | Te trae hacia él y encadena un golpe | **Línea** celeste entre él y vos; tu cuerpo tiembla 0,6 s antes |
| 8 | Gancho | Se engancha a un punto y cae ahí con un golpe | **Círculo** rojo donde va a caer |
| 9 | Desarme | Te saca el arma de metal | Tu arma **brilla celeste** 0,8 s; salís de su alcance (15 m) o rompés la línea de visión |
| 10 | Imán de monedas | Junta las monedas sueltas y te las devuelve | **Líneas** rojas finas desde cada moneda |
| 11 | Atracción masiva | Tira de todo lo que tenga metal en 14 m y lo junta alrededor | **Círculo** celeste grande con flechas hacia adentro; después **anillo** rojo alrededor de él |
| 12 | Embestida (peltre) | Se lanza en línea recta | **Franja** roja del ancho de su cuerpo hacia vos |
| 13 | Martillazo (peltre) | Golpe al suelo, onda de 6 m que aturde | **Círculo** rojo alrededor de él |
| 14 | Furia (peltre) | 8 s más fuerte y rápido | Aura **naranja** intensa (sin rojo) |
| 15 | Último aliento (peltre, pasiva) | Una vez: al bajar del 20 %, 3 s intocable y se cura | Aura **dorada** + nombre |
| 16 | Marca del cazador (estaño) | Te marca: 10 s sus golpes te hacen más daño | Borde rojo **sobre vos** y un ícono en la HUD |
| 17 | Mente despejada (estaño) | 12 s inmune a tus empujes y emociones | Aura **blanca** |
| 18 | Aplacar (latón) | Te baja aguante y velocidad 6 s | **Cono** violeta (no daña; ralentiza) |
| 19 | Enardecer (cinc) | Enfurece a los koloss y soldados cercanos | Onda **violeta** desde él |
| 20 | Nube de cobre | Esconde su quemado: tu bronce no lo siente | Bruma **gris** de 10 m (sin daño) |
| 21 | Atium | 6 s esquiva tus golpes y monedas | Siluetas **doradas**; destello dorado al empezar |

## Poderes extra (feruquimia, inventados)

| # | Poder | Qué hace | Aviso |
|---|---|---|---|
| 22 | Peso de hierro | Salta alto, se hace pesadísimo y cae aplastando | **Círculo** rojo en el piso que te sigue y se fija 1 s antes de caer, con su sombra |
| 23 | Ligereza de hierro | Se hace liviano: dos saltos largos seguidos | Aura **verde**; cada caída marca un **círculo** chico |
| 24 | Fuerza de peltre | Crece (×1,3) 10 s: golpes comunes más fuertes y de más alcance | Crece a la vista + aura **verde** |
| 25 | Mente de oro | Se cura mucho; se corta si le pegás fuerte | Aura **verde-dorada** + nombre (no hay zona: es tu momento de atacar) |
| 26 | Paso de acero | Velocidad: aparece detrás tuyo y golpea | **Círculo** rojo chico detrás tuyo, 0,7 s |
| 27 | Ola de calor (latón) | Anillo de calor que se expande desde él: hay que saltarlo | **Anillo** rojo que avanza; saltalo |
| 28 | Lluvia de monedas | Monedas cayendo del cielo en una zona amplia | Varios **círculos** rojos chicos al azar, cada uno se llena antes de que caiga su moneda |
| 29 | Tormenta de ceniza (final) | Solo en fase 3: bruma oscura, golpes de área seguidos | **Círculos** rojos en tandas, con huecos seguros marcados |

## Reglas para PvP y cooperativo (pendiente de decidir)

- Una sola función decide a quién afecta cada golpe o área: equipo y modo de juego.
- Tus áreas se ven en rojo para un rival y de otro color para tus aliados.
- En red, el servidor anuncia forma y momento del aviso; todos lo dibujan igual y el daño lo resuelve el servidor.
