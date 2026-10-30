# Kredik Shaw: especificación arquitectónica (primera pasada)

Kredik Shaw es la fortaleza, el palacio, la sede del Ministerio de Acero y el centro religioso del Imperio Final, todo en uno. Este documento traduce las imágenes de referencia (la ilustración exterior, las plantas de la planta baja, los niveles 2 a 5 y los subniveles 1 a 3, el despiece por niveles y el corte) a una especificación que el juego ya implementa:

- `scripts/world/kredik_plan.gd`: los datos de las plantas.
- `scripts/world/kredik_citadel.gd`: el exterior que se ve desde la ciudad.
- `scripts/world/kredik_level.gd`: los mapas interiores, uno por nivel.

Los cambios en las plantas se hacen en `kredik_plan.gd`; el resto se reconstruye solo.

---

## 1. Análisis de las referencias

| Referencia | Qué aporta | Cómo se usa |
|---|---|---|
| Ilustración exterior | Masa y silueta: cuatro torres redondas almenadas enormes, una nave catedralicia con dos agujas en la fachada y un piñón central, pináculos y arbotantes, muralla con matacanes, portal con rastrillo, ciudad baja alrededor, roca en primer plano y bruma | Exterior (`KredikCitadel`) |
| Planta baja (dos versiones) | Esquema general: muralla exterior rectangular con torres cuadradas en las esquinas, puertas oeste y este y Gran Entrada al sur; muralla interior con cuatro torres redondas; torreón con bastiones redondos y patio interior; complejo del trono al norte; Ministerio al oeste; complejo inquisitorial al este; cuarteles y patio de armas al noreste; franja sur con salones; almacenes entre murallas | Planta de todos los niveles y del exterior |
| Niveles 2 a 5 | Mismo perímetro y núcleo; cambia el uso de cada bloque: administración, Ministerio de Acero, altos cargos y dominio privado | `_l2`, `_l3`, `_l4`, `_l5` |
| Subniveles 1 a 3 | Bloque excavado bajo el torreón: rotonda al norte, bloque octogonal al oeste, salón central, bloque este y franja sur; salidas de emergencia al oeste; pozo vertical | `_sub1`, `_sub2`, `_sub3` |
| Despiece | Orden vertical (SL3 → SL1 → PB → N2 → N5), la Gran Escalera (niveles 2 a 5), las torres con varios pisos y el pozo secreto al SL3 | Conexiones entre niveles (`KredikPlan.links`) |
| Corte | El Salón del Trono ocupa dos alturas; los subniveles están en la roca; la entrada está al pie de la fortaleza, con la ciudad abajo | Alturas de las salas; meseta de roca |

**Escala.** Las plantas están a 1:1000 y la imagen mide 1408 × 768 px. Se usa **0,15 m por píxel**: la muralla exterior mide **198 × 95 m** y el torreón 46 × 35 m. Las celdas de los cuarteles quedan en unos 4 m, lo que encaja con la escala de una persona.

**Orientación.** El norte de los planos es −z en el juego. La Gran Entrada mira al sur (+z), hacia el centro de Luthadel.

---

## 2. Organización general

### Relación con la ciudad

- **Meseta de roca:** la fortaleza se apoya en una meseta llana a **8 m** sobre la ciudad.
- **Cordón de picos:** rodea la meseta en una franja de **20 a 36 m** de ancho con estribaciones y valles irregulares, con crestas de entre 20 y 60 m y agujas de roca. Sus pendientes no se pueden subir caminando.
  - El único paso es el **desfiladero de la rampa** de la Gran Entrada: 16 m de ancho y 34 m de largo, con pretiles.
  - Hay que entrar por la puerta o cruzar volando con acero o hierro.
- **Visibilidad:** la aguja del Lord Legislador llega a unos **130 m**, las agujas gemelas de la fachada a unos 110 m y las torres redondas a unos 60 m. Ningún edificio de la ciudad pasa de 30 m, así que Kredik Shaw se ve desde casi todas partes y es el centro visual del mapa.
- **Bruma:** siempre la envuelve.
  - De noche es un velo gris y se ven algunas ventanas encendidas.
  - De día es bruma negra y no hay ninguna luz.
- **Calle de ronda:** una calle rodea el cordón. Las casas, los callejones y las farolas no se meten en la zona reservada (`CityPlan.near_hill`).

### Esquema en planta (de afuera hacia adentro)

1. **Muralla exterior**: 15 m de alto, 3 m de grueso.
   - Matacán corrido, almenas a los dos lados del adarve, contrafuertes y troneras.
   - Cuatro torres cuadradas en las esquinas, que hacen de puestos de vigía.
   - Puertas oeste y este (torres gemelas y rastrillo cerrado).
   - **Gran Entrada** al sur: dos torres redondas con techo cónico, arco ojival, rastrillo levantado, estandartes rojos y escudo.
2. **Patio exterior** entre las dos murallas, con almacenes y alas de servicio.
3. **Muralla interior**: 19 m de alto, con cuatro torres redondas de 8 m de radio y 60 m de alto.
   - Las torres tienen corona de matacán y almenas y ventanas por pisos.
   - Puerta interior al sur, entre dos torres. Pasos al este, al oeste y al norte (la galería del trono).
4. **Torreón** en el centro:
   - Cuerpo de 26 m con cuatro bastiones redondos.
   - Nave catedralicia de 44 m con tejado de pizarra muy inclinado, pináculos en los aleros y arbotantes.
   - Fachada sur con dos torres de 58 m y sus agujas, un piñón con rosetón y un portal con arquivoltas.
5. **Galería del trono**: un puente cubierto hacia el norte que llega a la **nave del trono**.
   - La nave ocupa el centro de la muralla exterior norte.
   - Encima se alza la gran aguja: torre cuadrada, linterna octogonal y aguja.
6. **Bloques alrededor del torreón**:
   - Ministerio al oeste, con patios.
   - Cuarteles y Patio de Armas al noreste.
   - Complejo inquisitorial al este: anillo alrededor de un patio, con la **Torre del Inquisidor** de 84 m.
   - Franja sur con salones y cuarteles.
   - Dos torres de mensajería.

### Jerarquía

- **Afuera** (patio exterior, almacenes, franja sur): administrativo, con mucha gente.
- **Adentro** (Ministerio, complejo inquisitorial, torreón): político, con controles de guardia.
- **Arriba** (niveles 4 y 5, Consejo de los Seis, dominio del Lord Legislador): élite. Hay poca gente y los espacios son más grandes y más cargados de símbolos.
- **Abajo** (subniveles): misterio. Hay menos luz, más roca y laberintos, y nadie.

---

## 3. Nivel por nivel

Las medidas son aproximadas, en metros: ancho × fondo y alto libre. La seguridad va de 1 (pública) a 5 (el Lord Legislador).

### Subnivel 3 · Cimientos antiguos

| | |
|---|---|
| **Propósito** | Lo que había antes de Kredik Shaw: cimientos, cultos olvidados, secretos |
| **Salas principales** | Núcleo de la cisterna (pozo redondo de unos 21 m de diámetro, con agua), Laberinto (27 × 28 m), Estudio de artefactos olvidados (41 × 49 m, 7 m) |
| **Secundarias** | Cripta olvidada, Santuario de los dioses antiguos, Cisterna, Cripta de registros podridos, Archivos olvidados, Cámaras rituales, Bóveda del tesoro oculta (laberinto pequeño con cofres), Catacumbas, Depósito de secretos sin cartografiar, Pozo de acceso inferior |
| **Conexiones** | Pozo vertical (arriba, al SL2); Salida de la cueva (oeste, a la ciudad, al pie del cordón); el Pozo de acceso inferior baja más hondo y está cerrado: queda como misterio |
| **Seguridad** | 5 (por olvido, no por guardias) |
| **Estilo** | Roca viva, bóvedas toscas, agua negra, luz fría y escasa |
| **Narrativa** | Lo que el Ministerio esconde incluso de sí mismo |
| **Juego** | Exploración a oscuras con estaño; laberinto; cofres; rutas de escape secretas |
| **Hitos** | La cisterna redonda, el pozo sin fondo, la cueva de salida |

### Subnivel 2 · Archivos restringidos

| | |
|---|---|
| **Propósito** | Registros secretos y objetos confiscados |
| **Salas principales** | Archivos centrales restringidos (bloque oeste, 52 × 49 m) con la sala redonda de Registros seguros; Archivos centrales con cuatro bóvedas; Archivos laberínticos (laberinto de estanterías) |
| **Secundarias** | Depósito de registros secretos, Objetos confiscados (no metálicos), Inspección interna y seguridad, Bóveda de artefactos confiscados, Almacén de material restringido |
| **Conexiones** | Pozo vertical: sube al SL1 y baja al SL3 |
| **Seguridad** | 4 |
| **Estilo** | Muros macizos, estanterías hasta el techo, bóvedas con cofres |
| **Narrativa** | La memoria del Imperio: lo que se registró y lo que se ocultó |
| **Juego** | Sigilo entre estanterías; el laberinto; botín en las bóvedas. Casi no hay metal (“non-metal”): las anclas para acero y hierro escasean |
| **Hitos** | Las cuatro bóvedas, el laberinto de archivos |

### Subnivel 1 · Arsenal y cuarteles

| | |
|---|---|
| **Propósito** | Logística militar |
| **Salas principales** | Salón de recepción (cuarteles con literas, 41 × 49 m), Cuarteles (27 × 28 m), Centro militar de logística |
| **Secundarias** | Almacenes de víveres y Cámaras frías (sala redonda), Salas de meditación, Zona de descanso de la guardia, Almacenes de equipo táctico (armeros de hierro), Armerías, Almacenes de suministros, Rotonda abovedada al norte |
| **Conexiones** | Acceso imperial (escalera a la planta baja); Pozo vertical (al SL2); Salida de emergencia (oeste, a la ciudad) |
| **Seguridad** | 3 |
| **Estilo** | Bóvedas de piedra reforzada, funcional |
| **Juego** | Muchos armeros de hierro (anclas); combate en espacios cerrados |
| **Hitos** | La rotonda, las cámaras frías |

### Planta baja · Entrada imperial y Salón del Trono

| | |
|---|---|
| **Propósito** | Entrada pública, ceremonial y control |
| **Salas principales** | Entrada Imperial (Gran Entrada); Salón Procesional (28 × 13 m, 14 m, columnas y estandartes); Vía Procesional; Puerta interior; **Gran Salón** del torreón (37 × 12 m, 13 m); Patio interior con fuente; Galería del trono; **Salón del Trono** (28 × 20 m, 18 m, columnas, estrado de tres escalones y trono de hierro con respaldo de 6 m) |
| **Secundarias** | Cámara de audiencias públicas, salas de espera y controles de guardia del Ministerio, patios del Ministerio (estatua y fuente), despachos, Cuarteles de la Guardia y Patio de Armas, celdas y patio inquisitoriales, Sala segura, Recepción administrativa, alas de servicio, estudios privados, Estudio de Adan, almacenes |
| **Conexiones** | Gran Escalera oeste y este (al nivel 2); Puertas del subnivel (dentro del Salón Procesional, al SL1); Entrada Imperial (a la ciudad) |
| **Seguridad** | 1 en la franja sur, 2 en el Ministerio y el torreón, 4 en el Salón del Trono |
| **Estilo** | Monumental: columnas de mármol negro, alfombra roja con borde de oro, estandartes, lámparas de hierro |
| **Narrativa** | La primera impresión: el peso del Imperio |
| **Juego** | Patios abiertos para volar con acero; lámparas y columnas de hierro como anclas; botín en el Salón del Trono |
| **Hitos** | El trono, el patio interior, la Vía Procesional |

### Nivel 2 · Administración imperial

| | |
|---|---|
| **Propósito** | Burocracia: impuestos, censo, registros |
| **Salas principales** | Complejo de escribientes y Taller central de escribientes (filas de escritorios), Sala central de escribientes, Sucursal del censo de Luthadel, Sucursal de la Oficina del Censo |
| **Secundarias** | Archivos regionales, oficinas del censo, Puntos de recaudación, Puestos de admisión, oficinas de impuestos (celdas), centros de registros regionales, Almacén seguro, mensajería, clasificación de documentos, cuarteles |
| **Conexiones** | Gran Escalera: abajo a la planta baja, arriba al nivel 3 |
| **Seguridad** | 2 |
| **Estilo** | Pasillos largos y salas de trabajo repetidas: el Imperio como máquina |
| **Juego** | Infiltración entre escribientes; documentos |

### Nivel 3 · Ministerio de Acero y obligadores

| | |
|---|---|
| **Propósito** | El Ministerio: obligadores, investigación, audiencias de nobles |
| **Salas principales** | Tribunal de los Inquisidores de Acero (27 × 7 m, altar), Despacho del Alto Prefecto, Complejo del Archivo de los obligadores, Sala de trabajo del prefecto, Tribunal de cumplimiento burocrático |
| **Secundarias** | Cámaras de reunión y de recepción de nobles (mesas redondas), oficinas de la guardia, despachos de obligadores, Pasillos restringidos de acero, celdas del Ministerio, Control de la Guardia Real |
| **Conexiones** | Gran Escalera (niveles 2 y 4); **Acceso a la Torre del Inquisidor** |
| **Seguridad** | 3 o 4 |
| **Estilo** | Más oscuro y ceremonial; acero y altares |
| **Juego** | Puerta a la Torre del Inquisidor; espacios de interrogatorio |

### Nivel 4 · Altos cargos del Ministerio

| | |
|---|---|
| **Propósito** | Mando estratégico y seguridad |
| **Salas principales** | **Cámaras del Consejo de los Seis** (sala redonda de 23 m: doce sitiales de respaldo alto alrededor de una mesa redonda, 14 m de alto), Cuartel general de los Cantones con la **Mesa de los mapas**, Centro de mando fortificado |
| **Secundarias** | Control de la Llave Maestra, Mando de seguridad de los Cantones, Complejo de Inteligencia (archivo, sala secreta, Altas Salas, despachos), Relaciones Diplomáticas, suites de los altos obligadores (camas con dosel) |
| **Conexiones** | Gran Escalera (niveles 3 y 5) |
| **Seguridad** | 4 |
| **Estilo** | Lujo frío: mármol negro y oro |
| **Juego** | Información: mapas, archivos de inteligencia |

### Nivel 5 · Dominio del Lord Legislador

| | |
|---|---|
| **Propósito** | Lo privado y lo sagrado del Lord Legislador |
| **Salas principales** | **Alcoba del Lord Legislador** (redonda), Salón de recepción (41 × 49 m, columnas), Comedor privado, **Cámara de los Ancestros** con el Santuario interior, **Terrazas ajardinadas** (tres jardines redondos al aire libre: arriates, arbustos oscuros, árboles secos, fuente) |
| **Secundarias** | Cámaras de baño, Vestidor, Pasaje fuertemente custodiado, Biblioteca Imperial, Estudio sagrado, Salas de meditación, Salas de audiencias restringidas, cuarteles |
| **Conexiones** | Gran Escalera (abajo al nivel 4) |
| **Seguridad** | 5 |
| **Estilo** | Escala monumental, oro y luz cálida; vegetación escasa |
| **Narrativa** | El hombre detrás del dios |
| **Juego** | Las terrazas: salir al aire libre a 30 m y más |

### Torre del Inquisidor

- Ocho pisos redondos de 18 m de diámetro, unidos por rampas pegadas al muro:
  - Base de la torre.
  - Sala de guardia (armeros).
  - Archivo del Inquisidor.
  - Celdas.
  - Sala de interrogatorio.
  - Mensajería.
  - Observatorio (mesa de mapas).
  - Cima almenada.
- Tiene troneras con cristal y una lámpara de hierro en cada piso.
- **Conexión:** su base vuelve al nivel 3.

Las otras torres (vigía, mensajería y las cuatro grandes redondas) por ahora solo son volumen exterior y, desde fuera, anclas para acero y hierro.

---

## 4. Inconsistencias y faltantes, y cómo se resolvieron

| Problema en las referencias | Solución fiel a ellas |
|---|---|
| Las plantas son de imagen generada: los rótulos tienen errores (“Steral Inquisitor”, “Mast Ruler”, “Sesura”) | Se tradujeron por el sentido: Inquisidores de Acero, Lord Legislador, Sala segura |
| Hay dos salones del trono en la planta baja (el bloque norte y el torreón) | El bloque norte es el **Salón del Trono**, con el trono. El del torreón es el **Gran Salón**, la antesala ceremonial |
| La planta baja tiene dos versiones (una rotulada y otra más esquemática) | Se tomó la rotulada para los nombres y la esquemática para los volúmenes |
| Los patios de la planta baja (Patio interior, del Ministerio, Inquisitorial) quedan tapados en los pisos de arriba por talleres y tribunales | Cada nivel es un mapa propio. En la planta baja son patios abiertos; arriba son salas grandes. Los patios abiertos se reservan para la planta baja y las terrazas del nivel 5 |
| Las escaleras entre niveles no siempre coinciden en los planos | Se usan las **Grandes Escaleras** del torreón, que aparecen en todos los niveles (el despiece las marca de N2 a N5), además de las puertas del subnivel en el eje procesional y el **pozo vertical** de los cortes de los subniveles |
| La ilustración tiene torres redondas enormes; en la planta son pequeñas | Prima la silueta de la ilustración: las torres de la muralla interior se agrandaron (8 m de radio) sin mover su posición |
| La ilustración no muestra roca alrededor; el corte sí muestra la fortaleza alzada | Una meseta de 8 m con un cordón de picos que solo se cruza por la rampa |
| Los subniveles tienen otro contorno que la planta baja | Se respetó: un bloque excavado en la roca (todo lo demás es roca maciza) |
| Faltan las plantas de las torres | La Torre del Inquisidor se dedujo del despiece (“Inquisitor tower circulation shaft”, “Tower levels”) |
| No hay escala vertical | Se infirió del corte: planta baja de 11 a 18 m en los salones, pisos de 5,5 m, subniveles de 6 a 9 m, cuerpo del torreón de 26 m y nave de 44 m |

---

## 5. Documento listo para implementar

### Medidas clave (m; y = 0 en la meseta, que está 8 m sobre la ciudad)

| Elemento | Planta | Alto |
|---|---|---|
| Muralla exterior | 198 × 95, grosor 3 | 15 (+ almenas) |
| Torres de esquina (cuadradas) | 9 × 9 | 24 |
| Gran Entrada | torres de r 4,6 y vano de 8 | 26 + cono de 9 |
| Muralla interior | 155 × 63, grosor 3,5 | 19 |
| Torres de la muralla interior | r 8,2 | 50 + corona |
| Torreón (cuerpo) | 46 × 35 | 26 |
| Nave del torreón | 20 × 31 | 44 + tejado de 15 |
| Agujas de la fachada | 9 × 9 | 58 + aguja de 52 ≈ 110 |
| Nave del trono | 28 × 20 | 36 + tejado de 13 |
| Gran aguja del Lord Legislador | 11 × 11 | 64 + linterna de 10 + aguja de 56 ≈ 130 |
| Torre del Inquisidor | 9 × 9 | 66 + aguja de 18 |
| Cordón de picos | franja de 20 a 36 alrededor de la meseta, pie irregular | crestas de 20 a 60 sobre la ciudad |

### Materiales

- **Piedra volcánica oscura**: sillares con textura de Poly Haven (`castle_brick_07`, teñida casi negra) proyectada en coordenadas de mundo (`pbr_world.gdshader`).
- **Molduras** más oscuras para impostas, cornisas, marcos y matacanes.
- **Pizarra negra** en los tejados y las agujas, con **puntas de metal dorado**.
- **Hierro** en rastrillos, lámparas, armeros y el trono. **Mármol negro** pulido en columnas, estrados y sitiales.
- **Suelos** de losas grandes (`large_floor_tiles_02`).
- **Telas rojas** con remate de oro y **vidrieras** (`glass.gdshader`): oscuras, y algunas encendidas de noche.
- **Roca** de la meseta y del cordón: `rock_face_03`. Las texturas están en `assets/textures/polyhaven` (CC0, 1K).

### Ventanas y muros

- **Exterior:** fachadas por crujías (unos 4,6 m) con un contrafuerte entre cada crujía.
  - Una **ventana ojival** por crujía y piso: cristal, jambas, alféizar, parteluz, arco apuntado de dos piezas y gota encima.
  - **Imposta** en cada piso, **zócalo** y **cornisa** en todo el contorno.
  - Murallas con matacán corrido de modillones, troneras con marco y almenas.
  - Rosetón de 10 m (vidriera, anillo de 20 piezas y 12 radios) en el piñón de la fachada.
  - Arbotantes con pináculos.
- **Interior:**
  - **Puertas** con jambas y arco apuntado.
  - **Ventanas ojivales** con parteluz y travesaño de hierro en los muros que dan a un patio o al exterior.
  - En todos los muros: zócalo y cornisa.
  - En los salones: **pilastras** cada 5 m, **estandartes** rojos con remate de oro y **nervaduras** en el techo.

### Atmósfera

- **Bruma:** propia alrededor de la fortaleza y bancos de bruma que giran despacio. De día es negra y sin luces; de noche es gris, con un 10 % de ventanas encendidas.
- **Interior:** luz cálida de lámparas de hierro (2 a 6 por sala) y braseros en los patios.
  - Cuanto más abajo, menos luz. En el SL3 la luz es fría y falta en muchas salas.
  - En el nivel 5 la luz es más dorada.
- La ceniza y la lluvia siguen el clima de la ciudad.

### Cómo se construye en el motor

- **Planos de datos:** cada nivel es una lista de espacios (rectángulos o círculos en píxeles del plano, con tipo, mobiliario y alto), en `KredikPlan.spaces(nivel)`.
- **Cuadrícula de 1 m:**
  - Los espacios se pintan en orden.
  - Donde cambian se levantan muros. Las puertas se deciden solas: entre espacios de paso, vanos anchos; entre una sala y un pasillo, una puerta; las salas sin salida se abren a su vecina.
  - Las ventanas van en los muros que dan a patios o al exterior.
  - Suelos, techos y macizos se juntan en rectángulos grandes.
- **Mallas:** dos por nivel (sólida con colisión y decorativa sin colisión), guardadas en memoria tras la primera carga.
- **Conexiones:** en `KredikPlan.links(nivel)`. Las escaleras tienen rampa, rellano y una puerta arriba y otra abajo, y las salidas llevan a la ciudad. Se aparece en la sala correspondiente del otro nivel.
- **En pantalla:** un rótulo arriba a la izquierda dice el nivel y la sala.

### Pendiente para próximas pasadas

- **Gente:**
  - Guardias, obligadores e inquisidores, con menos gente cuanto más adentro y más arriba.
  - Patrullas y controles en las puertas de guardia.
- **Interiores de las demás torres:** vigía, mensajería y las cuatro grandes.
- **Interior desde afuera:** que los patios del exterior sean caminables con puertas reales a cada nivel, en lugar del único portal de la Gran Entrada.
- **Detalle fino:**
  - Vidrieras con dibujo.
  - Esculturas y tapices con iconografía del Ministerio.
  - Escaleras de caracol dentro de los bastiones.
- **Minimapa propio** para cada nivel interior.
