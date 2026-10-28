# Metales: qué hace cada uno quemado y avivado

Hoja de referencia del kit de alomancia del juego (lo acordado e implementado).
El oro y el electro quedan fuera.

## Controles

- **Tocar** la tecla de un metal: lo enciende o lo apaga.
- **Doble toque y mantener**: lo aviva mientras mantengas la tecla; al soltar vuelve a quemarse normal.
- **Tab** (mantener): rueda con todos los metales. Mové el ratón hacia uno y soltá Tab para
  encenderlo o apagarlo; clic izquierdo con la rueda abierta lo aviva.
- **N**: apaga todo.
- **Esc**: menú de pausa con todas las habilidades y controles.

La barra inferior del HUD muestra cada metal con su símbolo y color, la reserva como anillo
alrededor y la tecla debajo; quemando se ilumina y avivando tiene un halo que late. Debajo, la vida.

| Tecla | Metal |
|---|---|
| 1 | Acero |
| 2 | Hierro |
| 3 | Peltre |
| 4 | Atium |
| Z | Cinc |
| X | Cobre |
| C | Bronce |
| V | Estaño |
| B | Latón |

Acero y hierro encendidos a la vez: clic izquierdo tira, clic derecho empuja. Con uno solo,
cualquier clic usa ese.

## Físicos

| Metal | Quemado | Avivado |
|---|---|---|
| **Acero** (empujar) | Empuja metales hasta 40 m. | Doble de fuerza y 50 % más de alcance. Monedas como balas. |
| **Hierro** (tirar) | Tira de metales hasta 40 m. | Doble de fuerza y más alcance. |
| **Peltre** | 1,6× velocidad, 1,3× salto, +75 % daño, aguantás caídas de ~20 m, curación ×3. | 2,2× velocidad, el doble de daño y empuje, caídas de ~40 m. **Riesgo:** si se agota avivando, *arrastre de peltre*: 15 s lento y débil, sin poder quemarlo. |
| **Estaño** | Ves más lejos con bruma y de noche; los golpes te aturden menos tiempo. | Ves casi a través de la bruma y te recuperás aún antes. **Riesgo:** un relámpago te encandila ~1 s. |

## Mentales

| Metal | Quemado | Avivado |
|---|---|---|
| **Cinc** (enardecer) | El PNJ en la mira se enardece: ataca más seguido pero recibe +25 % de daño y no retrocede. Los ciudadanos se pelean. | Cono hacia delante: todos los que tengas enfrente. Los alománticos entran en *frenesí* y atacan a los suyos. |
| **Latón** (aplacar) | El PNJ en la mira deja de atacar (guardias dejan de perseguirte; ciudadanos no huyen). Un golpe rompe la calma. | Cono hacia delante. Un enemigo con menos del 30 % de vida se rinde. |
| **Cobre** | Nube: el bronce no te detecta. Inmune a cinc y latón enemigos. | Nube del doble de radio. |
| **Bronce** | Sentís a los alománticos que queman metales. | Más alcance. |

Enemigos nuevos: **Aplacador** (latón: aplacado no podés avivar) y **Encendedor** (cinc:
enardecido pegás +15 % pero recibís +25 %). El cobre te protege de los dos.

## Temporales

| Metal | Quemado | Avivado |
|---|---|---|
| **Atium** | Sombras del futuro de los demás (~0,6 s). Esquivás solo todos los golpes y monedas de quien no queme atium, y tus golpes le llegan aunque se mueva. | Cámara lenta (Sandevistan). |

**Lo único que contrarresta el atium es el atium.** Si los dos lo queman se anulan: nadie
esquiva solo, no hay cámara lenta y la sombra del rival se parte en futuros que saltan de un
lado a otro. Gana quien administre mejor su reserva: cuando a uno se le acaba, el otro esquiva
todo. Algunos nacidos de la bruma enemigos llevan atium y lo encienden si vos lo quemás o si
van perdiendo. El electro queda fuera del juego.

## Consumo (reserva llena)

| Ritmo | Metales | Quemado | Avivado |
|---|---|---|---|
| Casi permanente | Estaño, cobre, bronce | 5–7 min | ~1 min |
| Combate | Acero, hierro, cinc, latón | ~100 s | 20–25 s |
| Combate | Peltre | ~65 s | ~16 s |
| Escaso | Atium (reserva 30) | ~15 s | ~7 s |

Los frascos (T) recargan todo menos el atium.
