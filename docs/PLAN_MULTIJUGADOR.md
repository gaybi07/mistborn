# Plan por etapas: PvP y campaña cooperativa

Este plan lleva el prototipo actual a una batalla PvP entre dos computadoras y, después, a un RPG cooperativo por salas. Cada etapa debe quedar funcionando y verificable antes de comenzar la siguiente.

## Resultado buscado

El primer hito no es un MMORPG: es una arena privada para dos jugadores conectados a un servidor autoritativo.

El segundo hito es una sola misión cooperativa completa: entrar, combatir enemigos, obtener una recompensa y volver a una zona segura conservando el progreso.

## Decisiones que no se renegocian en cada etapa

| Tema | Decisión inicial |
|---|---|
| Red | API multijugador nativa de Godot con ENet/UDP |
| Autoridad | El servidor decide movimiento, impactos, daño, reservas y objetos físicos |
| Primera sala | Una instancia del servidor representa una partida |
| Jugadores | Dos durante el MVP; ampliar solo después de medirlo |
| Escenario inicial | `arena.tscn`; no sincronizar Luthadel todavía |
| Predicción | No al principio; agregarla solo si la latencia la vuelve necesaria |
| Persistencia | Ninguna durante el PvP inicial |
| Atium avivado | No usar `Engine.time_scale` en multijugador |
| Backend externo | Ninguno hasta tener una misión cooperativa jugable |

## Reglas de trabajo con Claude Code

Para cada etapa:

1. Pedir solamente esa etapa.
2. Exigir que lea los archivos afectados antes de editarlos.
3. Pedir una implementación mínima que reutilice Godot y el código existente.
4. No permitir cambios de formato o refactors no relacionados.
5. Preservar cambios existentes del usuario, incluidos los `.import` modificados.
6. Exigir una prueba reproducible y el resultado exacto.
7. Revisar el diff antes de avanzar.
8. Usar un commit por comportamiento terminado, con sus pruebas y documentación.

Plantilla para cerrar cada etapa:

```text
Antes de terminar:
- ejecuta las comprobaciones disponibles;
- describe el escenario manual exacto que probaste;
- muestra los archivos modificados y el resumen del diff;
- señala limitaciones conocidas sin implementar trabajo futuro;
- no hagas commit todavía.
```

## Hito A: PvP por Internet

### Etapa 0 — Congelar una base reproducible

**Objetivo:** saber que el juego actual abre y que los errores posteriores pertenecen al multijugador.

Trabajo:

- Confirmar la versión exacta de Godot usada por ambos desarrolladores.
- Abrir `main.tscn`, `arena.tscn` y `kredik_shaw.tscn` sin errores de scripts.
- Registrar cómo iniciar el proyecto y entrar a la arena.
- Separar los cambios automáticos de importación de cualquier cambio funcional.
- No refactorizar gameplay.

Aceptación:

- [ ] Los dos desarrolladores usan la misma versión de Godot.
- [ ] La arena funciona en modo individual.
- [ ] Se conocen los errores y advertencias preexistentes.
- [ ] `git status` no contiene cambios funcionales desconocidos.

Commit sugerido si hace falta documentación: `docs: registrar base reproducible del prototipo`

### Etapa 1 — Conectar dos procesos localmente

**Objetivo:** un proceso aloja y otro se conecta por `127.0.0.1`, sin crear todavía jugadores de red.

Trabajo:

- Crear un `NetworkManager` pequeño como autoload.
- Implementar `host`, `join` y `disconnect` con `ENetMultiplayerPeer`.
- Mostrar estado de conexión y errores en una interfaz mínima.
- Usar un puerto constante configurable en un solo lugar.
- Limitar inicialmente la sesión a servidor más dos clientes.

Aceptación:

- [ ] Se pueden abrir dos instancias del juego en la misma computadora.
- [ ] Una aloja y la otra se conecta.
- [ ] Ambas muestran los IDs de pares conectados.
- [ ] Cerrar un cliente no bloquea ni rompe al servidor.
- [ ] Un error de conexión se informa en pantalla.

Commit sugerido: `feat(network): conectar host y cliente por ENet`

### Etapa 2 — Dos jugadores en la arena

**Objetivo:** el servidor crea un personaje por conexión y cada cliente controla solamente el suyo.

Trabajo:

- Reutilizar `Player`; evitar crear una segunda clase de personaje.
- Hacer local solamente la lectura de input, cámara, HUD y audio del jugador propietario.
- Enviar input al servidor para que ejecute el movimiento.
- Replicar transformaciones y el estado mínimo necesario.
- Asignar puntos de aparición distintos y nombres basados en el `peer_id`.
- No agregar combate todavía.

Aceptación:

- [ ] Ambos jugadores aparecen en la arena.
- [ ] Cada teclado mueve un solo personaje.
- [ ] Cada cliente tiene una única cámara y HUD locales.
- [ ] Ambos ven una posición coherente del otro.
- [ ] Conectarse y desconectarse crea y elimina el personaje correcto.

Commit sugerido: `feat(network): replicar dos jugadores en la arena`

### Etapa 3 — Probar la conexión por Internet

**Objetivo:** repetir la etapa 2 desde dos redes diferentes.

Trabajo:

- Exportar un cliente de Windows.
- Exportar el mismo proyecto como servidor dedicado Linux/headless.
- Ejecutar una única instancia en un VPS con IP pública.
- Abrir únicamente el puerto UDP requerido.
- Permitir pasar IP y puerto al cliente sin recompilar.
- Registrar comandos de arranque y logs básicos de conexión.

Aceptación:

- [ ] Dos computadoras en redes distintas entran a la misma arena.
- [ ] El servidor no necesita GPU ni ventana.
- [ ] Una desconexión queda registrada y limpia el personaje.
- [ ] La partida soporta al menos diez minutos de movimiento sin divergir gravemente.

Commit sugerido: `feat(server): ejecutar la arena en servidor dedicado`

### Etapa 4 — Combate PvP mínimo

**Objetivo:** completar una pelea usando primero un único ataque cuerpo a cuerpo.

Trabajo:

- El cliente solicita atacar; el servidor valida alcance, estado y cooldown.
- El servidor aplica daño y empuje.
- Replicar vida, golpe, muerte y reaparición.
- Agregar una condición simple de victoria.
- No sincronizar todavía todas las armas ni combos.

Aceptación:

- [ ] Los dos clientes siempre muestran la misma vida.
- [ ] Solo el servidor puede confirmar daño.
- [ ] No se puede golpear fuera de alcance o ignorando el cooldown.
- [ ] Muerte, victoria y reaparición coinciden en ambos clientes.

Commit sugerido: `feat(pvp): resolver combate cuerpo a cuerpo en el servidor`

### Etapa 5 — Peltre

**Objetivo:** incorporar el metal con menos objetos de red.

Trabajo:

- El servidor controla estado, reserva y consumo del peltre.
- Replicar quemado, avivado y arrastre.
- Aplicar velocidad, salto, daño, resistencia y curación desde el estado confirmado.
- Los efectos visuales se generan localmente a partir del estado replicado.

Aceptación:

- [ ] La reserva coincide en ambos clientes y el servidor.
- [ ] El peltre modifica el combate sin permitir valores decididos por el cliente.
- [ ] El arrastre comienza y termina en el mismo momento para todos.

Commit sugerido: `feat(pvp): sincronizar peltre y su reserva`

### Etapa 6 — Acero y hierro sobre anclas fijas

**Objetivo:** validar la física alomántica sin monedas móviles.

Trabajo:

- Mantener las anclas de la arena como objetos conocidos por el servidor.
- El cliente propone el objetivo bajo la mira; el servidor valida distancia, metal y visibilidad.
- El servidor aplica fuerza al jugador y replica el resultado.
- Dibujar líneas y marcadores localmente.
- Probar empuje, tirón, dos agarres y liberación.

Aceptación:

- [ ] Los dos jugadores observan el mismo desplazamiento final.
- [ ] No se puede seleccionar un ancla fuera de alcance.
- [ ] Soltar el agarre detiene la fuerza en el servidor.
- [ ] Las líneas visuales no generan RPCs por fotograma.

Commit sugerido: `feat(pvp): autorizar acero e hierro contra anclas`

### Etapa 7 — Monedas y objetos metálicos móviles

**Objetivo:** sincronizar los objetos físicos que hacen especial al combate.

Trabajo:

- El servidor crea y elimina monedas y objetos replicados.
- El servidor es autoridad de sus transformaciones y colisiones.
- Implementar soltar, lanzar, empujar y tirar de una moneda.
- Aplicar límites de cantidad y frecuencia.
- Mantener efectos y trazos como presentación local.

Aceptación:

- [ ] Una moneda tiene la misma identidad para todos los pares.
- [ ] Impactos y daño se deciden una sola vez.
- [ ] Reconectar no duplica monedas.
- [ ] El límite de objetos evita crecimiento ilimitado.

Commit sugerido: `feat(pvp): replicar monedas y metales móviles`

### Etapa 8 — Resto de metales y atium multijugador

**Objetivo:** completar las habilidades PvP una por una.

Orden recomendado:

1. Estaño: principalmente presentación local con estado del servidor.
2. Cobre y bronce: detección calculada por el servidor.
3. Cinc y latón: efectos y duración validados por el servidor.
4. Atium: predicción, autoesquiva y contrarresto.

Para el atium avivado, reemplazar la cámara lenta global por mayor anticipación o una ventana de reacción. No cambiar `Engine.time_scale` en una partida compartida.

Aceptación:

- [ ] Cada metal tiene una prueba manual aislada.
- [ ] Reservas y efectos son autoritativos.
- [ ] Cobre bloquea detección y emociones de forma consistente.
- [ ] Atium contra atium cancela las ventajas correspondientes.

Commits sugeridos: uno por grupo de comportamiento, no uno gigante para todos los metales.

### Etapa 9 — Cerrar el MVP PvP

**Objetivo:** convertir las pruebas de red en una partida repetible.

Trabajo:

- Pantalla de espera para dos jugadores.
- Inicio cuando ambos están listos.
- Marcador, victoria, revancha y salida.
- Manejo de abandono del anfitrión o cliente.
- Prueba con latencia y pérdida de paquetes simuladas.
- Corregir solamente problemas observados; agregar predicción si la medición lo exige.

Aceptación del hito A:

- [ ] Dos personas de redes diferentes completan varias partidas.
- [ ] Movimiento, daño, metales y victoria no divergen.
- [ ] El servidor puede reiniciarse de forma documentada.
- [ ] Los errores importantes quedan en logs utilizables.

Commit sugerido: `feat(pvp): completar el ciclo de partida privada`

## Hito B: una misión cooperativa completa

No comenzar este hito hasta completar el PvP por Internet.

### Etapa 10 — Cooperativo contra un único tipo de enemigo

El servidor controla un grupo pequeño de enemigos en un escenario acotado. Ambos jugadores pueden dañarlos, ser derrotados y completar un objetivo común.

### Etapa 11 — Botín y progresión durante la sesión

El servidor decide recompensas, inventario, equipo y metales desbloqueados. Todavía se pierde todo al apagar la sesión.

### Etapa 12 — Persistencia mínima

Guardar en el servidor un perfil por jugador con versión de esquema: nivel, experiencia, metales, inventario y equipo. Empezar con archivos locales del servidor; usar una base de datos solo cuando haya una necesidad comprobada.

### Etapa 13 — Salas privadas

Reemplazar la IP manual por creación e invitación a salas. Inicialmente puede seguir siendo una instancia de servidor por sala. Elegir backend o servicio de plataforma recién en esta etapa.

### Etapa 14 — Una misión vertical de campaña

Construir una misión original y pequeña que pruebe el ciclo completo:

```text
Refugio -> preparación -> salida -> objetivo -> combate -> recompensa -> regreso
```

Debe poder completarse de principio a fin antes de producir más zonas o capítulos.

### Etapa 15 — Campaña por capítulos

Solo después de validar la misión vertical: niveles, desbloqueo de metales, jefes, narrativa y contenido hasta el enfrentamiento final. Revisar derechos de propiedad intelectual antes de una publicación pública o comercial basada directamente en personajes y trama de Mistborn.

## Señales para detenerse y corregir

No avanzar de etapa si ocurre alguno de estos casos:

- Un cliente puede aplicar daño directamente.
- Los dos clientes ven distinta vida, reserva o resultado de un impacto.
- Se agregan RPCs por fotograma para efectos puramente visuales.
- Una desconexión deja personajes u objetos huérfanos.
- Una etapa mezcla red, progresión, contenido y refactor general.
- No existe un escenario manual que otra persona pueda repetir.

## Primer paso

Ejecutar únicamente la etapa 0. Cuando esté verificada, preparar el prompt de la etapa 1 usando los resultados reales, especialmente la versión de Godot, errores preexistentes y forma de abrir dos instancias.
