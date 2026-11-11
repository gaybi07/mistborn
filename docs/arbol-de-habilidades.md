# Árbol de habilidades — diseño (borrador)

Estado: propuesta para confirmar. Todavía no hay código.

## Reglas acordadas

| Tema | Decisión |
|---|---|
| Techo | Jugador nivel 100; cada poder, nivel 5. El nivel de un metal es la suma de los puntos en sus poderes (ver `docs/PLAN_PROGRESION.md`) |
| Puntos | 3 al inicio y uno por nivel desde el 4 (100 en el nivel 100). Cada nivel de un poder cuesta 1 punto. Los metales sin poderes todavía (atium) se suben directo; atium cuesta 2 por nivel |
| Elección | Para poner un punto en un poder, todos los poderes de los que nace (en su rama) tienen que tener al menos 1. No alcanza para maxear todo |
| Reasignar | En cualquier momento, sin costo: "−" por poder (si ninguno que depende de él queda sin requisito) o "Devolver todos los puntos" |
| XP | Combate y objetivos, más un bonus chico por usar cada metal con tope por minuto |
| Inicio | Empuje básico, Tirón básico y Moneda de combate con 1 punto cada uno (los 3 del inicio). Opción "modo prueba" para desbloquear todo |
| Mejora | Cada poder escala con sus propios puntos (traducidos a la escala vieja 1-20 con `SkillTree.equiv_level`). El metal mejora con su nivel: gasta menos y su reserva crece (`SkillTree.METAL_SCALING`) |
| Combinadas | Se desbloquean solas cuando ambos metales llegan a 5 (escalón 1), 10 (escalón 2) y 15 (escalón 3) |
| Uso | 10 ranuras de habilidades activas con teclas reasignables. Las pasivas se aplican solas |
| Activación | Al apretar la tecla de una habilidad se queman solos los metales que necesita, hasta que termina o se aprieta otra vez la tecla. No hace falta tener el metal prendido antes |
| Sin reserva | La habilidad se apaga y queda en cooldown corto |
| Masa que se empuja | Acero/hierro: 1 kg (nivel 4), 5 kg (8), 25 kg (12), 100 kg (16), el propio cuerpo (20), usando la masa del objeto |
| Multijugador | Guardado local por jugador en `user://`; en PvP el servidor valida qué habilidades tiene cada uno |
| Cinc y latón en PvP | Contra jugadores solo un efecto leve (distorsión de pantalla o audio); el control completo es contra NPC |

### Decisiones de implementación

| Tema | Decisión |
|---|---|
| Ranuras | 12, con teclas por defecto `1 2 3 4 5 Q E F Z X C V`, reasignables. Las habilidades activas no se asignan solas: las asigna el jugador al aprenderlas. Solo se mantiene fijo el clic derecho para la moneda de combate |
| Metales | F1 a F9 encienden y apagan cada metal, en el orden de la barra del HUD (acero, hierro, peltre, atium, cinc, cobre, bronce, estaño, latón). También se enciende con clic sobre su icono en el HUD. Se mantiene el doble toque para avivar |
| Cursor | Mantener `Tab` libera el cursor para clicar los iconos del HUD; al soltarlo vuelve la cámara |
| Fases | 1) XP, nivel y HUD; 2) panel K; 3) bloqueo de metales y F1-F9; 4) ranuras y habilidades de acero, hierro y peltre; 5) servidor. Un commit por fase |
| Pasivas | Funcionan mientras su metal esté quemando |
| Activas | Se mantiene la tecla mientras se apunta (tirón, empuje, balanceo); las instantáneas (onda, anillo) son un toque con cooldown |
| Teclas viejas | Tirón (E), anillo y recoger monedas (Alt+E) y el resto de los gestos inventados dejan de existir y pasan a ranuras. E queda solo para interactuar |
| Metal bloqueado | Aviso corto y no se enciende |
| Habilidades existentes | Se usan con al menos 1 punto en el poder |
| XP | Valores base ×3 mientras se prueba: NPC común 60, guardia 180, jugador 300, y práctica de ~6 XP por segundo de metal en uso con tope de 180 por minuto |
| Menú | `K` abre el árbol como panel sin pausar: el cursor se libera y la cámara se frena, pero NPC y jugadores siguen moviéndose. Reasignar se puede hacer siempre. La pausa vive en el menú general (Esc); en multijugador la decide el host |
| Servidor | El juego debe quedar pensado para servidor, pero hoy se prueba en LAN: el cliente manda su progreso al conectarse y quien aloja lo acota y guarda una copia por jugador |

A = activa (ocupa ranura). P = pasiva (automática).

## Habilidades por metal

### Acero
| Nivel | Habilidad |
|---|---|
| 2 | A · Moneda de combate: clic derecho; hay que desbloquearla con el primer punto de acero. Sobre lo fijo a menos de 25 m queda clavada al instante y empuja (recarga 1 s); si no, sale como proyectil de 60 m/s. Cayendo sale hacia abajo; en el aire un aro suave avisa cuando lo apuntado está al alcance |
| 1 | A · Empuje básico: viene puesto desde el inicio en la tecla Q; empuja el metal de la mira (lo fijo o más pesado que tu poder te empuja a ti, lo más liviano sale despedido) |
| 3 | A · Ráfaga de monedas: siempre una cantidad impar, con una moneda al centro (donde apuntas): 3 en el nivel 3 y 2 más cada 2 niveles; ráfaga ancha desde el 15 |
| 8 | A · Escudo de monedas: 8 monedas giran en órbitas inclinadas (una más por nivel, 20 en el 20) y dan una probabilidad de desviar cada golpe cuerpo a cuerpo (40 % con 8, +3 % por moneda); no se gastan; dura 5,5 s y se retira solo |
| 12 | A · Campo magnético: 5 s en los que las monedas y proyectiles enemigos que se acercan (3,5 m) vuelven hacia quien los lanzó; recarga 12 s |
| 20 | A · Lanza de acero: gasta 5 monedas en un proyectil muy veloz que atraviesa hasta 4 enemigos con mucho daño y empuje; recarga 4 s |

### Hierro
| Nivel | Habilidad |
|---|---|
| 1 | A · Tirón básico (viene puesto en la tecla E): trae monedas y objetos más livianos que tú; si tiras de algo fijo o más pesado (farolas, rejas, techos metálicos), te acerca a ti |
| 4 | A · Arrastre: tira de un enemigo con metal hacia ti (1,5 s a 16 m/s) y lo deja aturdido 1 s al llegar; solo a quien pese hasta tu poder de tirón. Recarga 6 s |
| 2 | A · Imán de monedas: atrae nivel + 1 monedas dentro de un abanico hacia adelante; todas alrededor desde el 15 |
| 8 | A · Gancho: clava una moneda en cualquier superficie fija a menos de 25 m y una soga te tira hacia ella; frenas al llegar y los golpes casi no duelen un momento. Gasta 1 moneda. Recarga 3 s |
| 12 | A · Desarme: el arma del enemigo sale despedida y cae al piso a mitad de camino entre él y tú; 8 s pega un 70 % menos. Recarga 8 s |
| 20 | A · Atracción masiva: arrastra a todos los enemigos con metal en 12 m a un anillo a tu alrededor y los aturde 1,2 s. Recarga 20 s |

### Peltre
| Nivel | Habilidad |
|---|---|
| 1 | P · Resistencia: con peltre encendido, más aguante y menos daño y empuje recibidos |
| 4 | A · Embestida: te lanzas hacia donde miras 0,4 s; a quien toques lo golpeas, empujas y aturdes 1,5 s. Recarga 8 s |
| 8 | P · Golpe reforzado: más daño cuerpo a cuerpo |
| 12 | A · Martillazo: onda de choque de 6 m en el suelo que daña, empuja y aturde 1,2 s. Recarga 12 s |
| 16 | P · Último aliento: si un golpe te dejaría bajo el 20 % de vida, sobrevives, eres intocable 3 s y te curas un 40 %. Se activa sola. Recarga 60 s |
| 20 | A · Furia: 8 s con el peltre avivado sin gastar metal y +30 % de daño; luego quedas sin aliento. Recarga 45 s |

### Estaño
| Nivel | Habilidad |
|---|---|
| 1 | P · Sentidos agudos: el efecto base del estaño (ver más lejos en la bruma y la noche, recuperarte antes de un golpe) |
| 4 | A · Foco: 5 s de zoom (campo de visión −40 %) y +25 % de probabilidad de crítico. Recarga 20 s |
| 8 | P · Oído agudo: con estaño quemando ves a la gente cercana (22 m) tras las paredes como siluetas de humo con 0,5 s de retraso y estelas |
| 12 | A · Marca del cazador: marcas a un enemigo 15 s; lo ves tras paredes nítido (0,2 s de retraso) y recibe +25 % de daño tuyo. Recarga 25 s |
| 16 | A · Mente despejada: 12 s casi inmune a encandilar, aplacar/enardecer, empujones, tambaleo y guardia rota; limpia lo que tengas. Recarga 30 s |
| 20 | A · Sentidos extremos: 12 s viendo a todos hasta 45 m tras paredes, en tiempo real y más marcados. Recarga 35 s |

### Cinc
Cada poder enciende una emoción en los NPC (código: `ZincPowers` y los estados de `Npc`). Quien quema cobre lo
resiste; los jefes (`Champion`) no se dejan domar. Rama: Ira → Contagio emocional; Pánico → Avaricia → Domar; la
Tormenta pide Contagio y Domar. Cada nivel de un poder alarga su duración un 15 %.

| Nivel | Habilidad |
|---|---|
| 1 | A · Ira: enardece al NPC en la mira 10 s; ataca más seguido, recibe +25 % de daño y no retrocede. Si mata a otro NPC mientras dura, te llevás el 50 % de la experiencia. Recarga 12 s |
| 4 | A · Pánico (miedo): el NPC en la mira suelta la guardia y huye 8 s (un guardia abandona su puesto); los que están a 8 m y lo ven huir se asustan la mitad. Recarga 20 s |
| 8 | A · Avaricia (codicia): lanzás una moneda adonde apuntás y los NPC a 12 m van a buscarla 6 s, sin hacerte caso. Cuesta una moneda. Recarga 18 s |
| 12 | A · Domar (lealtad): un NPC común te sigue y pelea por vos 45 s (los de más de 100 de vida, un 45 % de eso; los jefes no se dejan). Toda la experiencia de lo que mate es tuya. Uno a la vez. Recarga 40 s |
| 16 | P · Contagio emocional: la Ira y el Pánico se pasan a los que están a 6 m, con la mitad de duración |
| 20 | A · Tormenta de emociones: en 15 m, 20 s: ira a los que pelean (se atacan entre ellos y te llevás el 50 % de la experiencia de esas muertes), pánico a los ciudadanos y lealtad al más débil de los que pelean. Recarga 60 s |

### Latón
El espejo frío del cinc: apaga a la gente en vez de moverla (código: `BrassPowers` y los estados de `Npc`). Quien
quema cobre lo resiste; los jefes no se rinden y en la Paz absoluta solo quedan desalentados. Rama: Calma →
Desaliento → Rendición; Sosiego → Sosegar multitud; la Paz absoluta pide Rendición y Sosegar.

| Nivel | Habilidad |
|---|---|
| 1 | A · Calma: el NPC en la mira deja de atacarte y se olvida de vos 10 s; un golpe tuyo lo despierta. Recarga 12 s |
| 4 | A · Desaliento: 10 s pegando un 40 % menos, más lento y sin bloquear ni esquivar. Recarga 15 s |
| 8 | P · Sosiego: con latón encendido te notan desde la mitad de distancia (guardias, soldados de misión, koloss, espectros) |
| 12 | A · Rendición: un enemigo con menos del 30 % de vida se rinde, suelta el arma y el botín, y te da la mitad de su experiencia. Recarga 20 s |
| 16 | A · Sosegar multitud: cono de 10 m, todos calmos 6 s. Recarga 30 s |
| 20 | A · Paz absoluta: en 15 m y 15 s nadie ataca a nadie; los jefes quedan desalentados. Recarga 60 s |

### Cobre
Sigilo y defensa contra la alomancia (código: `CopperPowers`; los NPC te pierden con `Npc.lose_track` y te ven según
`Player.concealment`). Rama: Nube → Silencio → Desvanecerse; Nube → Nube compartida → Mente cerrada; Fantasma pide
Desvanecerse y Mente cerrada.

| Nivel | Habilidad |
|---|---|
| 1 | P · Nube de cobre: lo de siempre; el bronce no te detecta y sos inmune al cinc y al latón ajenos |
| 4 | P · Silencio: con cobre encendido te notan desde el 60 % de la distancia y el estaño de un Ojo de estaño no le sirve |
| 8 | A · Desvanecerse: los que te tenían de objetivo (35 m) te pierden 4 s; tu próximo golpe hace +50 %. Recarga 20 s |
| 12 | A · Nube compartida: 15 s, tu domado y los aliados a 8 m quedan bajo tu nube, inmunes. Recarga 30 s |
| 16 | P · Mente cerrada: aunque no quemes cobre, lo emocional ajeno te dura la mitad y el Aplacar del Lord te saca la mitad de aliento |
| 20 | A · Fantasma: 10 s en que ningún NPC te ve; atacar lo termina con un crítico (doble de daño). Recarga 60 s |

### Bronce
Leer al enemigo: qué quema, cuándo ataca y dónde se esconde (código: `BronzePowers`; apagar metales ajenos con
`Allomancy.drain`). Rama: Pulsos → Leer metales → Anticipar; Pulsos → Pulso perturbador → Rastreo; Contrapulso pide
Anticipar y Rastreo.

| Nivel | Habilidad |
|---|---|
| 1 | P · Pulsos: lo de siempre; sentís a los alománticos que queman metales (no a los que tapa una nube de cobre) |
| 4 | P · Leer metales: arriba de cada alomántico que sentís, qué metales quema |
| 8 | P · Anticipar: el pulso brilla medio segundo antes de que use un poder |
| 12 | A · Pulso perturbador: 8 s sin nubes de cobre a 15 m; los Humeadores no pueden quemar cobre. Recarga 25 s |
| 16 | A · Rastreo: 20 s con los alománticos a 60 m en la brújula y el mapa. Recarga 40 s |
| 20 | A · Contrapulso: les apaga todos los metales 4 s a los alománticos enemigos a 12 m (libertad respecto de los libros). Recarga 60 s |

### Atium (máximo nivel 10, 2 puntos por nivel)
| Nivel | Habilidad |
|---|---|
| 1 | A · Premonición breve (ya existe) |
| 5 | A · Esquiva perfecta |
| 10 | A · Monedas guiadas (ya existe el guiado) mejoradas |

## Habilidades combinadas (12 pares × 3 escalones)

Escalones: 5 / 10 / 15 en ambos metales. Todas se activan solas al quemar los dos metales.

| Par | Escalón 1 | Escalón 2 | Escalón 3 |
|---|---|---|---|
| Acero + Peltre | Moneda reforzada (más fuerte y rápida) | Impulso explosivo (salto de acero con patada de peltre) | Lluvia de acero (anillo de monedas con daño multiplicado) |
| Hierro + Peltre | Balanceo veloz | Tirón de fuerza (arrastrar sin perder resistencia) | Gancho de titán |
| Acero + Hierro | Vuelo fino (cambio de ancla sin perder inercia) | Doble ancla (empujar y tirar a la vez con más control) | Maestría del cielo (vuelo libre con menos consumo) |
| Acero + Estaño | Puntería (ves la trayectoria) | Anclas lejanas resaltadas | Tiro perfecto |
| Hierro + Estaño | Ver anclas a larga distancia | Anclas ocultas | Mapa de anclas |
| Peltre + Estaño | Reflejos | Contraataque | Sentidos de guerrero |
| Peltre + Atium | Golpe preciso | Esquiva y contragolpe | Danza de batalla |
| Acero + Atium | Moneda guiada mejorada | Disparo que rebota | Tormenta guiada |
| Estaño + Bronce | Rastreo fino | Seguir a un alomante | Caza |
| Cobre + Bronce | Escudo y rastreo | Nube con alarma | Nube invisible |
| Cinc + Latón | Control emocional mixto | Emociones encadenadas | Dominio total sobre NPC |
| Cobre + Estaño | Sigilo básico | Sigilo silencioso | Sombra |

Total: 51 habilidades base + 36 combinadas = 87. Se propone implementarlas por fases (primero el sistema y acero/hierro/peltre).

## Pendiente de confirmar

- Las habilidades listadas son un punto de partida; cada nombre y efecto se puede cambiar.
- La habilidad de empuje ligero pasó de nivel 3 a nivel 4 para encajar en el patrón 1/4/8/12/16/20.
- Habilidades que ya existen en el juego y quedarían asociadas al árbol (hoy están disponibles desde el inicio): peltre, estaño, cobre, bronce, atium, cinc y latón.

## Estado de la fase 4

- Funcionan: ranuras (12, teclas reasignables), Tirón básico, Empuje ligero, Ráfaga de monedas, Imán de monedas, la moneda de combate (clic derecho), los límites de masa por nivel y las pasivas de peltre (Resistencia, Salto, Golpe, Aterrizaje, Segundo aliento).
- Pendientes (se ven como "próximamente"): Furia. Cada habilidad tiene un tooltip en el árbol (K) con lo que hace y cómo mejora.
- Tirón básico y Empuje ligero se comportan igual con el objetivo (el que está dentro del círculo de la mira, con reselección automática; el agarre se suelta al salir del alcance útil de ese objeto). Poder de empuje y de tirón = tu peso (70 kg) en el nivel 1, +15 % por nivel (143 kg en el 8, 270 kg en el 20): lo más liviano que ese poder sale despedido y casi no te mueve; lo fijo o más pesado te mueve a ti. La fuerza sube un 3 % por nivel y con los hitos Tirón ligero y Tirón de masa (hierro). La moneda de combate solo te empuja cuando choca con algo fijo o más pesado que tu poder.
- Teclas que cambiaron: anclar pasó a `Y` y la bolsa a `B`, porque `R` y `F` son ranuras por defecto.
- En red (fase 5): el cliente manda su nivel y el de cada metal al servidor, que lo acota a lo que pagan sus puntos y lo guarda por jugador. Las ranuras se envían como habilidad + objetivo y el servidor comprueba que esté desbloqueada. Quedan fuera por ahora la XP en red (matar a otro jugador no da experiencia) y el guardado en el servidor: cada cliente guarda su propio archivo.

## HUD (barra inferior y lista de metales)

- **Barra inferior** (`AbilityHud`), al estilo de League of Legends: retrato en vivo del personaje con la experiencia como un arco dorado alrededor, el nivel en un círculo abajo a la derecha y, abajo a la izquierda, los puntos de alomancia sin gastar. En fila, la Moneda de combate (clic derecho) y las ranuras 1 a 4 con su icono y su tecla; donde van los hechizos del LoL, Empuje básico (Q) y Tirón básico (E); más a la derecha, el resto de las ranuras. Debajo, vida (verde) y resistencia (azul) con sus números.
- **Lista de metales** (`MetalList`) en el borde izquierdo, vertical y discreta: un icono circular por metal con su reserva y su tecla (F1 a F9); con `Tab` sostenido se puede clicar.
