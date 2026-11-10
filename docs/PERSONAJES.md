# Personajes: estado y tareas

Cómo se usa: hacés una tarea **P**, dejás el zip en `Descargas/MESHY 3D` y me decís, por ejemplo, «P3 listo». Yo ejecuto lo que dice esa tarea y la tacho acá.

Última revisión: 5/11/2026, leyendo los clips que tiene adentro cada `.glb`.

## 1. Lo que ya tenés

| Personaje | Archivo | Clips | Se usa para | Qué le falta |
|---|---|---|---|---|
| Encapuchado | `MistbornHood` | 43 | Jugador, y por ahora inquisidor y Mistborn de casa | Subir un borde |
| Terrisano | `Terrisano` | 17 | Jugador y Sazed | Subir un borde |
| Kelsier | `Kelsier` | 2 | Jugador | Subir un borde. Sus golpes como NPC (P11) |
| Vin | `Vin` | 177 | Jugador, y biblioteca de clips para todos | Subir un borde. Sus golpes como NPC (P20) |
| Lord Legislador | `LordRuler` | 17 | Jefe final | Elegir clips para 3 poderes (P24) |
| Koloss adulto | `KolossAdulto` | 17 | Enemigo y koloss jefe | Nada |
| Koloss joven | `KolossJoven` | 14 | Enemigo | Un rugido mejor (P16) |
| Obligador | `Obligador` | 16 | Enemigo y Marsh | Nada |
| Gordo noble | `GordoNoble` | 14 | Lord Hastings y nobles | Nada |
| Skaa y obrero | `Skaa`, `SkaaObrero` | 48 y 49 | Gente de la ciudad | Nada |
| Clubs, Tindwyl, Ham, Breeze, Dockson | `Clubs`, `Tindwyl`, `Ham`, `Breeze`, `Dockson` | 2 | Frente al taller | Nada: el resto sale de la biblioteca |
| Elend, Straff | `Elend`, `Straff` | 2 | Casa Venture | Nada |
| Cett | `Cett` | 2 | Sentado frente a la Asamblea | Una silla propia: hoy usa un banco |
| Jastes | `Jastes` | 2 | Dársena | Nada |
| Niño y niña skaa (ella también hace de Tesa) | `NinoSkaa`, `NinaSkaa` | 2 | Distrito Skaa; Tesa en los corrales | Nada |
| Guardia imperial | `Soldado` | 2 | Cuartel del sur y Ministerio | Nada |
| Mataneblino | `Mataneblino` | 2 | Bosque Muerto | Un arma de madera propia: hoy usa el bastón de duelo |
| Nena skaa | `SkaaPilgrim` | 8 | Gente de la ciudad | Cara deformada: falta una versión con textura (P25) |

`Mistborn_Meshy.glb` no lo usa ningún script: se puede ignorar.

**Faltan 6 personajes por modelar:** Spook, Yomen, espectro, violento, lanzamonedas e inquisidor. Están abajo, en el orden en que los pide la historia.

**Ritmo:** cada personaje tiene el suyo, en `Art.HEROES`, `Art.CIVILIANS` y `Champion.KITS`.

**Clips que todavía no existen:** subir un borde, y hablar parado (`Discuss_While_Moving` habla caminando).

**Listos pero sin conectar, porque el juego todavía no los pide:** sentarse (`Chair_Sit_Idle_F`), abrir una puerta (`open_door_3`), levantar a un compañero (`Pull_Radish` es lo más parecido) y saltar un obstáculo (`Parkour_Vault_1`).

**No hace falta que generes:** koloss jefe (adulto más grande), patrulla (soldado con menos vida), guardia de casa (soldado con otros colores) y kandra (usa el cuerpo que copia). De esos me encargo yo.

## 2. La regla que te ahorra créditos

Todos los modelos riggeados en Meshy con esqueleto de Mixamo pueden compartir clips. Ya está probado: los clips de Vin se ven bien en Kelsier, el terrisano, el noble, el obligador y el koloss. Entonces:

- **Clips comunes:** ya están, en la biblioteca de Vin (`Art.MESHY_CLIPS`). Lo que los personajes no traen, lo toman de ahí.
- **Personaje nuevo:** alcanza con el modelo con textura y riggeado.
- **Clips propios:** solo si querés que se mueva distinto, como la caminata renga de Clubs. Son opcionales.

**Para los modelos:** de cuerpo entero, en pose T, sin armas en la mano (las pone el juego) y sin capas largas sueltas, que se deforman al riggear. Los textos de abajo son una base desde lo que recuerdo del libro: cambialos si algo no te cierra.

**Para los clips:** los nombres de Meshy no importan. Elegí el que más se parezca a lo que pido.

**Formato de entrega:** igual que `TERRISANO.zip`: FBX «animated mixamo All animation» con su textura, y el zip con el nombre del personaje. Si los clips salen en varias tandas, un zip por tanda, como hiciste con el encapuchado.

## 3. Lo que ejecuto en cada entrega

1. Convierto con `tools/blender/meshy_to_glb.py` a `assets/meshy/<Nombre>.glb`.
2. Compruebo el esqueleto y que estén los clips pedidos. Si falta algo, te lo digo antes de seguir.
3. Saco una hoja de cuadros de frente y de costado, la miro y te la paso si algo se ve raro.
4. Lo registro en el juego: como NPC (`Art.CIVILIANS`), enemigo (`Champion.KITS`) o jugador (`Art.HEROES`).
5. Lo pongo en el mapa para probarlo y te mando una captura.
6. Actualizo `scripts/story/story.gd`, corro `story_check` y tacho la tarea.

## 4. Tus tareas, en orden

### Primera tanda: el arranque de la historia

- [x] **P1. Clips comunes.** Hecho con los 12 zips de Vin. Los conectados están en `HeroClips`. Para terminar faltan dos clips: subir un borde y hablar parado.
- [x] **P2. Clubs.** Solo modelo riggeado. Opcional: caminata renga.
  - `Gnarled middle-aged male carpenter, scarred weathered face, permanent scowl, short gray hair, stocky build, plain worn brown work clothes and leather apron, full body, T-pose, no weapons`
  - **Yo:** lo pongo en el taller.
- [x] **P3. Soldado imperial.** Solo modelo riggeado.
  - `Imperial soldier, dark steel breastplate and helmet over ash-stained leather, grim fantasy, full body, T-pose, no weapons in hands`
  - **Yo:** armo sus golpes y saco de él la patrulla y el guardia de casa.
- [x] **P4. Tesa.** Usa el modelo de la niña skaa (`NinaSkaa`), por decisión del 5/11.
  - **Yo:** ubicada en los corrales.
- [x] **P5. Espectro de la bruma.** Hecho en G3: modelo sin esqueleto (masa de bruma con huesos), se mueve con shader. Modelo riggeado con clips propios: caminar o arrastrarse, atacar, morir.
  - `Mistwraith, pale translucent gaunt creature with mismatched bones visible under gelatinous skin, humanoid proportions, full body, T-pose`
  - El del libro no tiene forma humana, y puede que Meshy solo riggee cuerpos humanos: por eso este texto lo acerca a un humano. Si no lo riggea, avisame y lo pensamos.
  - **Yo:** armo sus ataques y lo pongo en las afueras.

### Segunda tanda: maestros y banda (Acto 1)

- [ ] **P6. Spook.** `Lanky teenage skaa boy, thin, messy hair, worn dark street clothes, full body, T-pose, no weapons`
- [x] **P7. Ham.** `Very muscular man, square jaw, short brown hair, sleeveless vest with bare arms, simple trousers, full body, T-pose, no weapons`
- [x] **P8. Breeze.** `Plump well-groomed man in his forties, elegant dark noble suit and vest, confident smug expression, full body, T-pose, no weapons`
- [x] **P9. Dockson.** `Stocky man in his thirties, short dark beard, tidy practical dark suit, calm expression, full body, T-pose, no weapons`
- [x] **P10. Tindwyl.** `Tall stern Terris woman in her forties, brown hair in a tight bun, long robe with colorful V-shaped patterns, large metal bracers on forearms, rows of earrings, full body, T-pose`
- **Yo, en todos:** los pongo en el taller o en su lugar. Spook, Ham y Breeze además pelean, porque se pueden elegir de aliados.

### Tercera tanda: Acto 2

- [x] **P11. Kelsier.** Riggeado y elegible. Me queda armarle los golpes como aliado o rival (Y13).
- [x] **P12. Mataneblino.** `Imperial hazekiller soldier wearing only leather and cloth, no metal at all, wooden shield on back, full body, T-pose, no weapons in hands`
  - **Yo:** le hago un arma de madera. El acero y el hierro no le hacen nada.
- [ ] **P13. Violento.** `Huge muscular allomancer brute, bare scarred arms, dark leather harness, intimidating, full body, T-pose, no weapons`
- [ ] **P14. Lanzamonedas.** `Lean agile allomancer, dark fitted clothes, pouch belts for coins, full body, T-pose, no weapons`
- [x] **P15. Jastes Lekal.** `Thin nervous young nobleman, thinning hair, wrinkled expensive suit, anxious expression, full body, T-pose, no weapons`
- [ ] **P16. Rugido del koloss joven.** Opcional: un rugido o grito. Lo demás ya lo toma de la biblioteca.

### Cuarta tanda: Acto 3

- [x] **P17. Obligador.** Ya no hace falta generar nada: toma de la biblioteca estar parado y recibir golpe.
- [ ] **P18. Inquisidor.** Solo modelo riggeado.
  - `Tall gaunt hairless Steel Inquisitor, thick steel spikes through both eyes, intricate tattoos around the eyes, long dark robe, full body, T-pose, no weapons`
  - **Yo:** le cambio el modelo al kit que hoy usa el encapuchado.
- [ ] **P19. Yomen.** `Thin bald obligator, intricate tattoos around the eyes, small bead on the forehead, gray robes, composed expression, full body, T-pose, no weapons`

### Quinta tanda: Acto 4 y final

- [x] **P20. Vin.** Riggeada y elegible, con 1,55 m. Me queda armarle los golpes como aliada o rival (Y13).
- [x] **P21. Elend Venture.** `Slim young nobleman, tousled brown hair, slightly disheveled dark suit, books in coat pockets, kind thoughtful face, full body, T-pose, no weapons`
- [x] **P22. Straff Venture.** `Tall hard-faced middle-aged nobleman, severe black suit, cold expression, full body, T-pose, no weapons`
- [x] **P23. Cett.** `Scruffy bearded middle-aged lord, unkempt rumpled noble suit, sly expression, full body, T-pose, no weapons`
  - En el libro no puede caminar y lo llevan en una silla: necesita «sentado» de P1. Yo armo la silla.
- [ ] **P24. Poderes del Lord Legislador.** No hace falta generar: Y14 elige en la biblioteca los clips de Empujón, Tirón y Regeneración (hoy un puñetazo, un tajo y una caminata renga).
- [ ] **P25. Nena skaa con textura.** Volver a exportar Patchwork Pilgrim, esta vez con su textura.
  - **Yo:** reemplazo el archivo y compruebo la cara.

## 5. Lo que hago yo sin que generes nada

Cada una se pide con su número, por ejemplo «Y2, dale».

**Personajes**
- [x] **Y1.** NPC y enemigos usan clips compartidos.
- [x] **Y18.** Hecho en G4: los NPC del Acto 1 dan sus misiones. Los de los otros actos, con su acto.
- [ ] **Y2.** Koloss jefe: adulto más grande, con más vida y otros poderes.
- [ ] **Y3.** Kandra: pelea con el cuerpo que copia, sorteado entre Dockson, Breeze y Spook. Después de P6, P8 y P9.
- [ ] **Y4.** Colores de capa, para que dos jugadores puedan repetir personaje.
- [ ] **Y13.** Golpes y poderes de Kelsier y Vin como aliados o rivales.
- [ ] **Y14.** Clips de la biblioteca para los 3 poderes del Lord Legislador.
- [x] **Y15.** Efectos de todos los poderes del jugador, con ondas y bruma (`scripts/fx/air_fx.gd`).
- [ ] **Y16.** Los mismos efectos en Lord Legislador, koloss, obligadores e inquisidores.
- [x] **Y17.** Postura, caminata y golpes según el arma (`HeroClips.STANCES`), y enemigos que pelean a puños si les sacan el arma (`Champion.FIST_BLOWS`).

**Lugares**
- [x] ~~**Y5.** Foso de ceniza.~~ Hecho en G2.
- [x] **Y6.** Aldeas del Camino Sur. Hecho en G6 (falta revisar).
- [ ] **Y7.** Campamento koloss.

**Juego** (en este orden, de [HISTORIA.md](HISTORIA.md))
- [ ] **Y8.** Medir si Luthadel aguanta cuatro jugadores en red.
- [ ] **Y9.** Los cuatro caminando y peleando juntos en la ciudad.
- [x] **Y10.** Conversaciones, cuaderno, marcas del mapa y guardado en tres partidas.
- [x] **Y11.** Hecho en G5 (falta revisar). Primer tramo jugable: principales 1 y 2, más una secundaria con consecuencia. Necesita P2, P3, P4, P5 e Y5.
- [ ] **Y12.** Sacar al Lord Legislador de la Puerta Oeste y dejar libre la moneda de combate.
- [ ] **Y19.** Aterrizaje de héroe: skill nueva que combina peltre y empuje de acero, todavía sin diseñar. Clip listo: `Dive_Down_and_Land_2`, tramo del 18 % al 65 % (cae con una mano al piso y se levanta).
