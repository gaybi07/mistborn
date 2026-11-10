# Historia y flujo del juego

Plan acordado. Todavía no hay nada de esto jugable: el juego no usa estos datos.

- **Misiones, NPC, lugares y consecuencias:** `scripts/story/story.gd`. Se edita ahí.
- **Prueba y generación:** `tools/story/story_check.gd`. Comprueba que toda partida llegue al final, y genera los dos archivos de abajo.
- **Diagrama y tablas:** [HISTORIA_FLUJO.md](HISTORIA_FLUJO.md). No editar a mano.
- **Mapa interactivo:** `historia_mapa.html`. No editar a mano; su diseño está en `tools/story/mapa_plantilla.html`.

```bash
C:/Users/gabih/Downloads/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/story/story_check.gd
```

## La trama

Parecida al libro, sin calcarla. Mismo mundo, mismos personajes y solo monstruos del libro, pero otros hechos.

Un grupo de skaa queda atrapado en un foso de ceniza por algo que hicieron en los tejados. Al escapar se les despierta la alomancia, y Sazed los lleva con Clubs. Cerca de Luthadel aparecen koloss donde no debería haberlos, y el ejército imperial mira para otro lado.

Tirando de ese hilo descubren clavos del Ministerio en un koloss jefe: el Ministerio hace a los koloss y los suelta cuando quiere castigar a alguien, y las casas nobles pagan por usarlos contra sus rivales. Kelsier, a quien daban por muerto, vuelve con un plan propio. Además, alguien de la mesa de la banda no es quien parece: un kandra copió a Dockson, a Breeze o a Spook.

El final depende de a quién ayudaron. Se entra a Kredik Shaw por uno de cuatro caminos, y el Lord Legislador llega más débil según lo que hicieron.

## El arranque

1. Se juntan en la sala y cada uno elige personaje: encapuchado o terrisano. Sin origen ni aspecto propios. Arrancan con moneda y tirón básicos.
2. Una patrulla los persigue por los tejados del barrio skaa, y aprenden a moverse.
3. Los atrapan y los mandan a un foso de ceniza, de donde se fugan.
4. Cruzan las afueras en la bruma: espectros chicos, y koloss a lo lejos.
5. Sazed los lleva al taller de Clubs.
6. Los maestros muestran los estilos: Volador (Spook), Peleador (Ham), Manipulador (Breeze) y Sigiloso (Clubs). Es solo información: se puede saltear y volver a consultar. El árbol de habilidades sigue igual, con 1 punto por nivel.
7. Se abre el mundo.

## La columna principal

Doce tramos, en este orden, con dos o tres misiones abiertas a la vez dentro de cada uno. Nunca se pierden, y si cae el NPC que las da, las da otro.

1. Tejados y foso
2. Taller de Clubs y elección de estilo
3. Primeros koloss
4. Koloss jefe
5. Ejército koloss en la Puerta Este
6. Ejército humano, mataneblinos y brumosos
7. Obligadores
8. Inquisidor
9. Escolta mixta de obligadores y guerreros
10. Baile y casas nobles
11. Mistborn de las casas
12. Lord Legislador

## Cómo te enterás de qué hacer

| Vía | Para qué | Qué pasa en el mapa |
|---|---|---|
| Un NPC te la da, o la banda avisa en el taller | Principales | Punto exacto |
| Rumores y carteles | Secundarias, y consecuencias que se acercan | "?" en una zona |
| Descubrirla al llegar | Secundarias y guardianes | Aparece el punto al acercarse |
| Cuaderno | Lo pendiente, lo que sabés y lo que pasó | La que elijas seguir va a la brújula |

Hay mapa de ciudad y mapa de región. Marcas: principal, secundaria, rumor, maestro, guardián, tienda y refugio; cada tipo se puede ocultar.

Las conversaciones son una caja de texto básica con opciones.

**Hecho en G1** (con una misión de prueba, `prueba_plaza`: Dockson te manda a leer un cartel en la plaza):

- Conversaciones: `scripts/story/dialogues.gd` (texto, opciones y lo que hace cada una) y `scripts/ui/dialogue_box.gd`. Los NPC con conversación muestran "[E] Hablar con …" (`QuestTracker`).
- Estado de la historia: `scripts/story/quest_log.gd` (misiones en curso con su paso, hechas, lo que sabés, lo que pasó). Los pasos de una misión van en `"steps"`: llegar a un lugar o hablar con alguien.
- Cuaderno (J): `scripts/ui/journal_window.gd`. Brújula arriba: `scripts/ui/compass_bar.gd`. Marcas en el mapa y el minimapa, con flechas al borde para lo que queda afuera y casillas para ocultar cada tipo: `scripts/ui/city_map.gd`.
- Tres partidas: `scripts/story/save_slots.gd` y la pantalla de inicio `scripts/ui/start_screen.gd` (también en Esc → Partidas). Se guarda al terminar cada misión y al salir.
- Prueba: `tools/story/quest_check.gd`. Falta: rumores ("?" en el mapa), mapa de región y red.

## Decisiones y consecuencias

- Las decisiones pueden cerrar misiones y cambiar aliados y el final, pero siempre se puede terminar.
- Las secundarias tienen consecuencias medidas por principales cumplidas, no por tiempo. Un rumor avisa una principal antes, y queda escrito en el cuaderno. Algunas se pierden.
- Los NPC importantes mueren solo por una decisión o una consecuencia avisada.
- Perder una pelea no castiga las principales: reaparecen en el sótano de Clubs y reintentan.

## El mundo

- Ciudad y afueras abiertas, con el peligro avisado.
- Kredik Shaw está rodeada por bruma mortal, que primero avisa y oscurece, y después mata. Desaparece cuando la historia abre el lugar. También frena a quien quiera entrar volando.
- Mansiones: guardias que te echan y, si insistís, pelean.
- Monstruos comunes y guardias reaparecen en minutos. Los guardianes vuelven tras varias misiones cumplidas, y su recompensa única se da una sola vez.

## Grupo

- De 1 a 4 jugadores desde el principio, juntos desde la sala. Se puede entrar en cualquier momento.
- El anfitrión es el líder y puede pasarle el mando a otro, pero la partida sigue guardada en su máquina. Si se va, se guarda y termina para todos.
- El líder acepta y decide. Todos ven las misiones y las marcas. Antes de una decisión o un jefe importante se avisa a todos y se esperan unos segundos.
- Cada uno anda libre por el mapa. Se pueden repetir personajes, con otro color de capa.
- Los NPC hablan en plural; jugando solo, en singular. Algunas frases cambian según el personaje del líder.
- Experiencia compartida. Los objetos son de quien los agarre primero.
- Un aliado por grupo, elegido por el líder en el taller. Si cae, se recupera.
- Si caés te pueden levantar. Si caen todos, reaparecen en el sótano de Clubs.
- Cada jugador extra suma 50 % de enemigos comunes y 60 % de vida en jefes, a ajustar al probarlo.
- Conexión por IP, y Steam o un servicio similar antes de publicar.
- Tres partidas guardadas, con guardado automático al terminar cada misión y al salir.

## Orden de construcción

1. **Medir** si Luthadel aguanta cuatro jugadores en red.
2. **Red:** los cuatro caminando y peleando juntos en la ciudad. Hoy la red solo funciona en la arena y el juego acepta pocas conexiones (`NetworkManager.MAX_CLIENTS`), así que este paso reemplaza lo que dice [PLAN_MULTIJUGADOR.md](PLAN_MULTIJUGADOR.md) sobre no sincronizar la ciudad.
3. **Primer tramo:** principales 1 y 2, más una secundaria con decisión y consecuencia, con conversación, cuaderno y marcas básicas. Hay que construir el foso.
4. **Personajes:** modelos y clips de los que falten, a medida que los pida cada tramo. La lista, con cada tarea, está en [PERSONAJES.md](PERSONAJES.md).

El Lord Legislador ya no espera en la Puerta Oeste (G8). La moneda de combate queda libre con la progresión nueva de Lucho: arranca con uno de los 3 puntos del inicio (`docs/PLAN_PROGRESION.md`); hasta entonces pide un punto en acero.
