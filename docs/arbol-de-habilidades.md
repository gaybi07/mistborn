# Árbol de habilidades — diseño (borrador)

Estado: propuesta para confirmar. Todavía no hay código.

## Reglas acordadas

| Tema | Decisión |
|---|---|
| Techo | Jugador nivel 100, cada metal nivel 20 (atium: máximo 10) |
| Puntos de alomancia | 1 por nivel de jugador (99 en total). Subir un nivel de metal cuesta 1 punto; atium cuesta 2 por nivel |
| Elección | Se puede subir cualquier metal, pero no alcanza para maxear todos (180 niveles posibles contra 99 puntos, más el costo de atium) |
| Reasignar | En cualquier momento fuera de combate, desde el menú, sin costo |
| XP | Combate y objetivos, más un bonus chico por usar cada metal con tope por minuto |
| Inicio | Acero y hierro en nivel 1; los otros metales se aprenden con su primer punto. Opción "modo prueba" para desbloquear todo |
| Habilidad nueva | En los niveles 1, 4, 8, 12, 16 y 20 de cada metal; en los demás niveles solo mejoran números (alcance, fuerza, consumo) |
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
| Ranuras | 12, con teclas por defecto `1 2 3 4 Q E R F Z X C V`, reasignables. Las habilidades activas no se asignan solas: las asigna el jugador al aprenderlas. Solo se mantiene fijo el clic derecho para la moneda de combate |
| Metales | F1 a F9 encienden y apagan cada metal, en el orden de la barra del HUD (acero, hierro, peltre, atium, cinc, cobre, bronce, estaño, latón). También se enciende con clic sobre su icono en el HUD. Se mantiene el doble toque para avivar |
| Cursor | Mantener `Tab` libera el cursor para clicar los iconos del HUD; al soltarlo vuelve la cámara |
| Fases | 1) XP, nivel y HUD; 2) panel K; 3) bloqueo de metales y F1-F9; 4) ranuras y habilidades de acero, hierro y peltre; 5) servidor. Un commit por fase |
| Pasivas | Funcionan mientras su metal esté quemando |
| Activas | Se mantiene la tecla mientras se apunta (tirón, empuje, balanceo); las instantáneas (onda, anillo) son un toque con cooldown |
| Teclas viejas | Tirón (E), anillo y recoger monedas (Alt+E) y el resto de los gestos inventados dejan de existir y pasan a ranuras. E queda solo para interactuar |
| Metal bloqueado | Aviso corto y no se enciende |
| Habilidades existentes | Se bloquean por nivel según el catálogo; lo básico sigue disponible desde el nivel 1 |
| XP | Valores base ×3 mientras se prueba: NPC común 60, guardia 180, jugador 300, y práctica de ~6 XP por segundo de metal en uso con tope de 180 por minuto |
| Menú | `K` abre el árbol como panel sin pausar: el cursor se libera y la cámara se frena, pero NPC y jugadores siguen moviéndose. Reasignar se puede hacer siempre. La pausa vive en el menú general (Esc); en multijugador la decide el host |
| Servidor | El juego debe quedar pensado para servidor, pero hoy se prueba en LAN: el cliente manda su progreso al conectarse y quien aloja lo acota y guarda una copia por jugador |

A = activa (ocupa ranura). P = pasiva (automática).

## Habilidades por metal

### Acero
| Nivel | Habilidad |
|---|---|
| 1 | A · Moneda de combate: lanzar moneda con clic derecho y empujarla |
| 4 | A · Empuje ligero: empujar con una ranura objetos de hasta 1 kg |
| 8 | A · Anillo de monedas: 8 monedas en círculo (hoy Alt+E con acero) |
| 12 | A · Escudo metálico: desvía proyectiles metálicos |
| 16 | P · Empuje pesado: objetos de hasta 100 kg |
| 20 | P · Onda de acero: sin tope de masa (anclas) y empuje en área (pendiente) |

### Hierro
| Nivel | Habilidad |
|---|---|
| 1 | A · Tirón básico |
| 4 | P · Tirón ligero: mueve objetos de hasta 1 kg |
| 8 | A · Imán de monedas: atrae las monedas cercanas al monedero |
| 12 | A · Desarme: tirar del arma metálica de un enemigo |
| 16 | P · Balanceo: permite tirar de anclas fijas |
| 20 | P · Tirón de masa: sin tope de masa |

### Peltre
| Nivel | Habilidad |
|---|---|
| 1 | P · Resistencia: más aguante y menos daño recibido |
| 4 | P · Salto reforzado (ya existe en Espacio+Espacio) |
| 8 | P · Golpe reforzado: más daño cuerpo a cuerpo |
| 12 | P · Aterrizaje seguro: sin daño de caída |
| 16 | P · Segundo aliento: recuperación lenta de vida |
| 20 | A · Furia: ráfaga de velocidad y daño, con cooldown |

### Estaño
| Nivel | Habilidad |
|---|---|
| 1 | P · Sentidos agudos (ya existe) |
| 4 | P · Visión nocturna |
| 8 | P · Oído agudo: ver pasos y enemigos tras paredes |
| 12 | A · Anticipación: marca el ataque inminente |
| 16 | A · Sentidos extremos: resalta a todos los enemigos en un rango |
| 20 | P · Percepción total: ve en 360° |

### Cinc
| Nivel | Habilidad |
|---|---|
| 1 | A · Provocar: un NPC se fija en ti |
| 4 | A · Enfurecer: ataca sin cuidado |
| 8 | A · Redirigir: ataca a otro NPC |
| 12 | A · Frenesí: enfurece en un área |
| 16 | P · Ira contagiosa: la furia se propaga |
| 20 | A · Ira masiva: enfurece a todos en rango |

### Latón
| Nivel | Habilidad |
|---|---|
| 1 | A · Calmar a un NPC |
| 4 | A · Sosegar en un área |
| 8 | A · Pacificar: el NPC deja de atacar |
| 12 | A · Persuadir: mejores ofertas y acceso a lugares |
| 16 | A · Calma profunda: aturde |
| 20 | A · Dominio emocional: controlar a un NPC por un rato |

### Cobre
| Nivel | Habilidad |
|---|---|
| 1 | A · Nube de cobre: oculta tus metales (ya existe) |
| 4 | P · Nube ampliada |
| 8 | P · Silencio: haces menos ruido |
| 12 | A · Nube compartida: cubre también a aliados cercanos |
| 16 | P · Mente cerrada: inmune a cinc y latón |
| 20 | A · Fantasma: invisible a los sentidos alománticos |

### Bronce
| Nivel | Habilidad |
|---|---|
| 1 | A · Detectar pulsos (ya existe) |
| 4 | P · Distinguir qué metal quema cada uno |
| 8 | P · Rastreo: indica la dirección de la fuente |
| 12 | P · Descifrar: intensidad y objetivo del metal que quema el otro |
| 16 | A · Pulso perturbador: rompe la nube de cobre cercana |
| 20 | A · Visión de la ciudad: muestra a todos los alomantes en el mapa |

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

- Funcionan: ranuras (12, teclas reasignables), Tirón básico, Empuje ligero, Anillo de monedas, Imán de monedas, la moneda de combate (clic derecho), los límites de masa por nivel y las pasivas de peltre (Resistencia, Salto, Golpe, Aterrizaje, Segundo aliento).
- Pendientes (se ven como "próximamente"): Escudo metálico, Onda de acero (el empuje en área), Desarme y Furia.
- Las anclas fijas pesan "infinito": el hierro solo tira de ellas desde el nivel 16 (Balanceo) y el acero las empuja desde el 20.
- Teclas que cambiaron: anclar pasó a `Y` y la bolsa a `B`, porque `R` y `F` son ranuras por defecto.
- En red (fase 5): el cliente manda su nivel y el de cada metal al servidor, que lo acota a lo que pagan sus puntos y lo guarda por jugador. Las ranuras se envían como habilidad + objetivo y el servidor comprueba que esté desbloqueada. Quedan fuera por ahora la XP en red (matar a otro jugador no da experiencia) y el guardado en el servidor: cada cliente guarda su propio archivo.
