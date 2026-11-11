class_name Story
## La historia como datos: quién, dónde, contra quién y qué abre cada misión. Se edita acá; tools/story/story_check.gd la
## prueba y genera docs/HISTORIA_FLUJO.md y docs/historia_mapa.html. Las reglas y el relato están en docs/HISTORIA.md.
##
## Una misión está disponible cuando se cumplen "needs" (todos) y "any" ([cuántos, de cuáles]), y no está bloqueada.
## Esas listas nombran misiones hechas o marcas que deja un final. Cada final deja sus "sets" y bloquea sus "locks".
##
## "kind": main (nunca se pierde; si su NPC muere la da "backup"), side, teacher (se puede saltear) o guardian.
## "spine": número en la columna de 12 misiones principales.
## "learn": cómo se entera el jugador: npc, banda, rumor o lugar. "heard": lo que oye o lee.
## "late": si la misión sigue sin hacer tras "after" misiones principales, pasa esto. "warn" es el rumor que avisa una antes.

const ACTS := {
	1: "Ceniza: de los tejados al taller",
	2: "Bruma: koloss y ejércitos humanos",
	3: "Acero: el Ministerio",
	4: "Casas: nobles y otros Mistborn",
	5: "Kredik Shaw",
}

## "at": XZ en el mapa, "city": si queda adentro de la muralla (se comprueba), "ready": si el lugar ya existe en el juego.
## "marks": lo que el lugar marca siempre en el mapa una vez conocido.
const PLACES := {
	"barrio_skaa": {"name": "Distrito Skaa", "at": Vector2(-100, 330), "city": true, "ready": true},
	"foso": {"name": "Foso de ceniza", "at": Vector2(-580, 330), "city": false, "ready": true},
	"camino_oeste": {"name": "Afueras del oeste", "at": Vector2(-470, 120), "city": false, "ready": true},
	"camino_sur": {"name": "Aldeas del Camino Sur", "at": Vector2(-20, 715), "city": false, "ready": true},
	"bosque": {"name": "Bosque Muerto", "at": Vector2(-620, 620), "city": false, "ready": true},
	"montes": {"name": "Faldas de los Montes de Ceniza", "at": Vector2(-300, -640), "city": false, "ready": true},
	"campamento": {"name": "Campamento koloss", "at": Vector2(640, -330), "city": false, "ready": true},
	"puerta_este": {"name": "Afuera de la Puerta Este", "at": Vector2(372, -147), "city": false, "ready": true},
	"taller": {"name": "Taller de Clubs", "at": Vector2(-60, 205), "city": true, "ready": true, "marks": ["refugio", "tienda"]},
	"sala_combate": {"name": "Sótano de Clubs: práctica de combate", "scene": "res://scenes/combat_room.tscn", "ready": true},
	"pista": {"name": "Sótano de Clubs: práctica de saltos", "scene": "res://scenes/nav_course.tscn", "ready": true},
	"corrales": {"name": "Corrales de carbón", "at": Vector2(-280, 250), "city": true, "ready": true},
	"forja": {"name": "Distrito de Forja", "at": Vector2(-270, 40), "city": true, "ready": true},
	"darsena": {"name": "Dársena", "at": Vector2(290, -10), "city": true, "ready": true},
	"mercado": {"name": "Mercado", "at": Vector2(70, -165), "city": true, "ready": true, "marks": ["tienda"]},
	"plaza": {"name": "Plaza Central", "at": Vector2(0, 0), "city": true, "ready": true},
	"asamblea": {"name": "Asamblea", "at": Vector2(-110, -85), "city": true, "ready": true},
	"cuartel_sur": {"name": "Cuartel del sur", "at": Vector2(90, 335), "city": true, "ready": true},
	"ministerio": {"name": "Ministerio del Acero", "at": Vector2(166, -208), "city": true, "ready": true},
	"hastings": {"name": "Casa Hastings", "at": Vector2(-150, -158), "city": true, "ready": true},
	"lorch": {"name": "Casa Lorch", "at": Vector2(-60, -175), "city": true, "ready": true},
	"venture": {"name": "Casa Venture", "at": Vector2(-222, -280), "city": true, "ready": true},
	"kredik": {"name": "Kredik Shaw", "at": Vector2(-4, -328), "city": true, "ready": true},
}

## "model": archivo de assets/meshy ("" = falta), "clips": si ya tiene su paquete de animaciones.
## "role": lo que su trato puede cambiar. "ally": puede acompañar al grupo cuando tenga clips.
const NPCS := {
	"clubs": {"name": "Clubs", "model": "Clubs", "clips": true, "role": "Dueño del refugio. Si cae, hay que mudar la base a la Dársena."},
	"terrisano": {"name": "Sazed", "model": "Terrisano", "clips": true, "ally": true, "role": "Guarda memorias: lleva al secreto de la Regeneración."},
	"tindwyl": {"name": "Tindwyl", "model": "Tindwyl", "clips": true, "role": "Lidera a los terrisanos refugiados. Apoya o cierra las misiones de Terris."},
	"ham": {"name": "Ham", "model": "Ham", "clips": true, "ally": true, "role": "Maestro del estilo Peleador."},
	"spook": {"name": "Spook", "model": "Spook", "clips": true, "ally": true, "role": "Maestro del estilo Volador. Puede ser el kandra."},
	"breeze": {"name": "Breeze", "model": "Breeze", "clips": true, "ally": true, "role": "Maestro del estilo Manipulador. Puede ser el kandra."},
	"dockson": {"name": "Dockson", "model": "Dockson", "clips": true, "role": "Organiza la banda. Puede ser el kandra."},
	"tesa": {"name": "Tesa", "model": "NinaSkaa", "clips": true, "at": Vector2(-280, 250), "role": "Capataza de los corrales. Lleva a los skaa al levantamiento, o deja de hablarte."},
	"kelsier": {"name": "Kelsier", "model": "Kelsier", "clips": true, "ally": true, "role": "Vuelve con un plan propio: lo seguís o lo enfrentás."},
	"vin": {"name": "Vin", "model": "Vin", "clips": true, "ally": true, "role": "Mistborn sin casa: aliada, rival o enemiga en el final."},
	"marsh": {"name": "Marsh", "model": "Obligador", "clips": true, "ally": true, "role": "Infiltrado en el Ministerio: abre la entrada por abajo, o te traiciona."},
	"elend": {"name": "Elend Venture", "model": "Elend", "clips": true, "role": "Heredero reformista: abre la entrada con invitación, o lo derrocás."},
	"straff": {"name": "Straff Venture", "model": "Straff", "clips": true, "role": "Te compra, o manda a su Mistborn a cazarte."},
	"hastings": {"name": "Lord Hastings", "model": "GordoNoble", "clips": true, "role": "Paga por los koloss. Se lo puede chantajear."},
	"cett": {"name": "Cett", "model": "Cett", "clips": true, "role": "Señor de otra ciudad, de visita. Trae soldados a tu favor o en tu contra."},
	"yomen": {"name": "Yomen", "model": "", "clips": false, "role": "Obligador que gobierna otra ciudad. Puede romper con el Ministerio."},
	"jastes": {"name": "Jastes Lekal", "model": "Jastes", "clips": true, "role": "Noble que manda koloss. Vende su secreto, o trae al ejército."},
	"kandra": {"name": "El kandra", "model": "", "clips": false, "ally": true, "role": "Copia a Dockson, Breeze o Spook (al azar). Se lo mata, se lo usa o se le compra el contrato."},
}

## Quiénes puede reemplazar el kandra: se sortea al empezar la partida. Sus misiones principales tienen otro NPC de respaldo.
const KANDRA_HOSTS := ["dockson", "breeze", "spook"]

## "kit": entrada de Champion.KITS ("" = todavía no pelea), "note": de qué se puede sacar. Monstruos solo del libro.
const FOES := {
	"patrulla": {"name": "Patrulla imperial", "kit": "Soldado", "note": "falta que tenga menos vida y persiga"},
	"espectro": {"name": "Espectro de la bruma", "kit": "", "note": "monstruo nuevo: modelo y clips propios"},
	"koloss_joven": {"name": "Koloss joven", "kit": "KolossJoven"},
	"koloss_adulto": {"name": "Koloss adulto", "kit": "KolossAdulto"},
	"koloss_jefe": {"name": "Koloss jefe", "kit": "", "note": "KolossAdulto más grande, con más vida y otros poderes"},
	"soldado": {"name": "Soldado imperial", "kit": "Soldado"},
	"mataneblino": {"name": "Mataneblino", "kit": "Mataneblino"},
	"violento": {"name": "Violento (peltre)", "kit": "", "note": "modelo y clips nuevos"},
	"lanzamonedas": {"name": "Lanzamonedas (acero)", "kit": "", "note": "modelo y clips nuevos"},
	"obligador": {"name": "Obligador", "kit": "Obligador"},
	"inquisidor": {"name": "Inquisidor", "kit": "MistbornHood", "note": "hoy usa el modelo del encapuchado: le falta el suyo"},
	"guardia_casa": {"name": "Guardia de casa noble", "kit": "", "note": "soldado con los colores de cada casa"},
	"mistborn": {"name": "Mistborn de casa noble", "kit": "MistbornHood", "note": "hoy usa el modelo del encapuchado"},
	"kandra": {"name": "Kandra", "kit": "", "note": "pelea con el cuerpo que está copiando"},
	"vin": {"name": "Vin", "kit": "", "note": "tiene clips: le falta armar sus golpes y poderes"},
	"lord_ruler": {"name": "Lord Legislador", "kit": "LordRuler"},
}

## Cómo llega el Lord Legislador a la pelea final según las marcas que dejaste: poderes de LordPowers.POWERS que pierde
## (van a LordPowers.off) y ayuda.
const FINALE := {
	"secreto_reserva": {"off": ["Mente de oro"], "text": "Vaciaron la reserva que lo cura."},
	"armadura_madera": {"off": ["Empuje de acero", "Tirón de hierro", "Atracción masiva", "Desarme"], "text": "Su equipo de madera no le da metal del que agarrarlos."},
	"aliada_vin": {"off": [], "text": "Vin pelea con ustedes."},
	"aliado_kelsier": {"off": [], "text": "Kelsier distrae a los inquisidores del salón."},
	"soldados_cett": {"off": [], "text": "Los soldados de Cett frenan a los refuerzos."},
	"yomen_rompe": {"off": [], "text": "Parte del Ministerio se queda afuera de la pelea."},
	"emboscada_kandra": {"off": [], "text": "El kandra los entregó: el último tramo arranca emboscados."},
}

## Qué cambia cada marca que dejan los finales y las consecuencias. Una marca sin efecto sería una decisión de mentira.
const MARKS := {
	"skaa_corrales": "Los skaa de los corrales suman al levantamiento.",
	"skaa_aldea": "Los sobrevivientes de la aldea suman al levantamiento.",
	"skaa_plaza": "Los rescatados de la plaza suman al levantamiento.",
	"dato_cuartel": "En El ejército que no sale ya saben por dónde entrar.",
	"tesa_enojada": "Tesa deja de dar misiones y no apoya el levantamiento.",
	"tienda_pobre": "Menos monedas y frascos en la tienda del taller.",
	"amigo_terris": "Abre el camino al secreto de la Regeneración.",
	"mensajero_muerto": "Tindwyl desconfía: hay que ganársela antes de seguir con Terris.",
	"sabe_carros": "Saben que los koloss llegan en carros: menos koloss en la Puerta Este.",
	"aldea_quemada": "Aparecen refugiados en el barrio skaa.",
	"secreto_koloss": "Saben cómo mandan a los koloss: el koloss jefe de la Puerta Este llega solo.",
	"aliado_kelsier": "Kelsier se puede elegir de aliado, y abre Ningún Venture.",
	"kelsier_rival": "Kelsier hace su plan por su lado y arruina alguna misión de las casas.",
	"sin_armeria": "Menos soldados en el camino final.",
	"armadura_madera": "En el final, el Lord Legislador no los puede empujar ni tirar.",
	"brumosos_aliados": "La banda de la Forja pelea con ustedes en la procesión.",
	"brumosos_enemigos": "La banda de la Forja pelea contra ustedes en la procesión.",
	"pista_kandra_1": "Primera pista del kandra.",
	"pista_kandra_2": "Segunda pista del kandra.",
	"pista_kandra_3": "Tercera pista: ya se lo puede enfrentar.",
	"pista_ministerio": "Saben dónde guardan a los presos: menos guardias en el Ministerio.",
	"aliado_marsh": "Marsh se puede elegir de aliado, y abre la entrada por abajo.",
	"planos_kredik": "Abre la entrada por abajo, sin Marsh y sin su ayuda.",
	"yomen_rompe": "Parte del Ministerio queda afuera de la pelea final.",
	"sabe_reserva": "Abre La reserva, que le saca la Regeneración.",
	"secreto_reserva": "En el final, el Lord Legislador no se puede curar.",
	"hastings_comprado": "Una puerta de atrás en Casa Venture durante el final.",
	"aliado_elend": "Abre la entrada a Kredik Shaw con invitación.",
	"cazador_straff": "Se suma un Mistborn más en Los que pelean de noche.",
	"soldados_cett": "Los soldados de Cett frenan a los refuerzos en el final.",
	"taller_perdido": "Cae Clubs, y la base y la tienda pasan a la Dársena.",
	"emboscada_kandra": "El último tramo arranca emboscados.",
	"kandra_aliado": "El kandra se suma y se puede elegir de aliado.",
	"aliada_vin": "Vin pelea con ustedes en el final.",
}

const QUESTS := {
	# ---------------------------------------------------------------- Acto 1: tutorial sin elegir, y después se abre todo
	"tejados": {"act": 1, "kind": "main", "spine": 1, "title": "Sobre los tejados", "giver": "", "place": "barrio_skaa", "needs": [],
		"learn": ["lugar"], "heard": "Arranca solo, apenas eligen personaje en la sala.",
		"goal": "Una patrulla los persigue por el barrio skaa. Se escapa saltando y frenando a los perseguidores.",
		"teaches": "Moverse, tirón básico, moneda básica", "foes": {"patrulla": 3},
		"ends": {"ok": {"text": "Los atrapan al final: no se puede evitar"}}},
	"foso": {"act": 1, "kind": "main", "spine": 1, "title": "El foso de ceniza", "giver": "", "place": "foso", "needs": ["tejados"],
		"learn": ["lugar"], "heard": "Despiertan encadenados: el capataz les dice dónde están.",
		"goal": "Trabajo forzado en el foso, y una fuga con otro preso herido.",
		"teaches": "Golpear, esquivar, levantar a un compañero", "foes": {"patrulla": 4},
		"ends": {"salvar": {"text": "Sacar al preso herido"}, "dejar": {"text": "Salir sin él"}}},
	"afueras": {"act": 1, "kind": "main", "spine": 1, "title": "Lo que hay de noche", "giver": "", "place": "camino_oeste", "needs": ["foso"],
		"learn": ["lugar"], "heard": "La brújula marca las luces de Luthadel a lo lejos.",
		"goal": "Cruzar las afueras en la bruma: espectros chicos, y koloss a lo lejos de los que conviene alejarse.",
		"teaches": "Mapa, brújula, cuaderno", "foes": {"espectro": 3},
		"ends": {"ok": {"text": "Sazed los encuentra y los lleva a Luthadel"}}},
	"el_taller": {"act": 1, "kind": "main", "spine": 2, "title": "Un carpintero que no hace preguntas", "giver": "terrisano", "backup": "clubs", "place": "taller", "needs": ["afueras"],
		"learn": ["npc"], "heard": "Sazed: «Conozco a un carpintero. Ustedes le interesan».",
		"goal": "Clubs les explica qué son. Se elige estilo y se gasta el primer punto en el árbol. Las pruebas de los maestros son opcionales.",
		"teaches": "Hablar, misiones, árbol de habilidades", "foes": {},
		"ends": {"ok": {"text": "Gastar el primer punto"}}},
	"t_volador": {"act": 1, "kind": "teacher", "title": "Estilo Volador", "giver": "spook", "place": "pista", "needs": ["el_taller"],
		"learn": ["banda"], "heard": "Clubs: «Si quieren volar, hablen con Spook».",
		"goal": "Hacer la pista de saltos.", "teaches": "Para qué sirven acero y hierro", "foes": {},
		"ends": {"ok": {"text": "Terminar o salir: se puede repetir"}}},
	"t_peleador": {"act": 1, "kind": "teacher", "title": "Estilo Peleador", "giver": "ham", "place": "sala_combate", "needs": ["el_taller"],
		"learn": ["banda"], "heard": "Clubs: «Ham los espera abajo».",
		"goal": "Aguantar las oleadas de práctica.", "teaches": "Para qué sirve el peltre", "foes": {"koloss_joven": 3},
		"ends": {"ok": {"text": "Terminar o salir: se puede repetir"}}},
	"t_manipulador": {"act": 1, "kind": "teacher", "title": "Estilo Manipulador", "giver": "breeze", "place": "mercado", "needs": ["el_taller"],
		"learn": ["banda"], "heard": "Clubs: «Breeze anda por el mercado. Cuiden los bolsillos».",
		"goal": "Calmar o encender a un mercado entero.", "teaches": "Para qué sirven latón y cinc", "foes": {},
		"ends": {"calmar": {"text": "Calmarlos: nadie sale herido"}, "encender": {"text": "Encenderlos: más botín, más guardias"}}},
	"t_sigiloso": {"act": 1, "kind": "teacher", "title": "Estilo Sigiloso", "giver": "clubs", "place": "barrio_skaa", "needs": ["el_taller"],
		"learn": ["banda"], "heard": "Clubs: «Si no quieren que los encuentren, vengan conmigo».",
		"goal": "Cruzar el barrio de noche sin que te encuentre un buscador.", "teaches": "Para qué sirven estaño y cobre", "foes": {},
		"ends": {"ok": {"text": "Terminar o salir: se puede repetir"}}},
	"corrales": {"act": 1, "kind": "side", "title": "La deuda de los corrales", "giver": "tesa", "place": "corrales", "needs": ["el_taller"],
		"learn": ["rumor", "npc"], "heard": "En la calle: «El capataz de los corrales cobra con los hijos».",
		"goal": "Resolver qué pasa con el capataz.", "foes": {"soldado": 4},
		"ends": {"pelear": {"text": "Echarlo a golpes", "sets": ["skaa_corrales"]},
			"pagar": {"text": "Pagar la deuda", "sets": ["skaa_corrales"]},
			"dato": {"text": "No meterse: lo que sabe vale más", "sets": ["dato_cuartel"]}},
		"late": [{"after": 5, "warn": "Dicen que el capataz prepara un escarmiento.", "text": "El capataz toma represalias, y Tesa deja de dar misiones.", "lost": true, "sets": ["tesa_enojada"]}]},
	"contrabando": {"act": 1, "kind": "side", "title": "Cajas que no existen", "giver": "dockson", "place": "darsena", "needs": ["el_taller"],
		"learn": ["banda"], "heard": "Dockson: «Hay un cargamento nuestro atascado en el puerto».",
		"goal": "Sacar del puerto el cargamento de metales.", "foes": {"soldado": 3},
		"ends": {"ok": {"text": "Sacarlo entero"}},
		"late": [{"after": 5, "warn": "En el puerto andan revisando las cajas.", "text": "Se pierde el cargamento: menos monedas y frascos en la tienda del taller.", "lost": true, "sets": ["tienda_pobre"]}]},
	"mensajero": {"act": 1, "kind": "side", "title": "Lo que come en el Bosque Muerto", "giver": "tindwyl", "place": "bosque", "needs": ["el_taller"],
		"learn": ["rumor", "npc"], "heard": "En la calle: «Un mensajero terrisano se metió al bosque y no volvió».",
		"goal": "Rescatar al mensajero de los espectros.", "foes": {"espectro": 6},
		"ends": {"ok": {"text": "Traerlo de vuelta", "sets": ["amigo_terris"]}},
		"late": [{"after": 6, "warn": "Tindwyl pregunta seguido por su mensajero.", "text": "El mensajero muere y Tindwyl desconfía: el secreto de la Regeneración cuesta más.", "lost": true, "sets": ["mensajero_muerto"]}]},
	"guardian_bosque": {"act": 1, "kind": "guardian", "title": "El guardián del bosque", "giver": "", "place": "bosque", "needs": ["el_taller"],
		"learn": ["lugar", "rumor"], "heard": "Al acercarse al centro del bosque, o por un rumor en el mercado.",
		"goal": "Un koloss adulto solo, entre los troncos. Primera recompensa única. Vuelve con el tiempo.", "foes": {"koloss_adulto": 1},
		"ends": {"ok": {"text": "Vencerlo"}}},

	# ---------------------------------------------------------------- Acto 2: koloss, y después los ejércitos humanos en cualquier orden
	"rastros": {"act": 2, "kind": "main", "spine": 3, "title": "Koloss donde no debería haber", "giver": "dockson", "backup": "clubs", "place": "campamento", "needs": ["el_taller"],
		"learn": ["banda"], "heard": "Dockson, en el sótano: «Alguien está trayendo koloss a las puertas».",
		"goal": "Meterse de noche al campamento y ver qué hay.", "foes": {"koloss_joven": 4, "koloss_adulto": 1},
		"ends": {"sigilo": {"text": "Entrar y salir sin que los vean", "sets": ["sabe_carros"]}, "sangre": {"text": "Abrirse paso a golpes"}}},
	"aldea": {"act": 2, "kind": "side", "title": "La aldea del Camino Sur", "giver": "tesa", "place": "camino_sur", "needs": ["el_taller"],
		"learn": ["rumor", "npc"], "heard": "En la Puerta Sur: «Los koloss bajan hacia las aldeas».",
		"goal": "Los koloss bajan a una aldea skaa.", "foes": {"koloss_joven": 6},
		"ends": {"evacuar": {"text": "Sacar a todos", "sets": ["skaa_aldea"]}, "emboscar": {"text": "Usarla de cebo y emboscar", "sets": ["sabe_carros"]}},
		"late": [{"after": 3, "warn": "Se ve humo al sur.", "text": "Queman la aldea, y aparecen refugiados en el barrio skaa.", "lost": true, "sets": ["aldea_quemada"]}]},
	"jastes": {"act": 2, "kind": "side", "title": "El noble de los koloss", "giver": "jastes", "place": "darsena", "needs": ["rastros"],
		"learn": ["rumor"], "heard": "En el puerto: «Hay un noble que compra carne para miles, y no tiene gente».",
		"goal": "Encontrar a Jastes Lekal.", "foes": {"guardia_casa": 4},
		"ends": {"comprar": {"text": "Comprarle el secreto de los koloss", "sets": ["secreto_koloss"]}, "matar": {"text": "Matarlo"}}},
	"jefe": {"act": 2, "kind": "main", "spine": 4, "title": "El que los manda", "giver": "ham", "backup": "clubs", "place": "montes", "needs": ["rastros"],
		"learn": ["banda"], "heard": "Ham: «Los rastros suben a los montes. Ahí está el grande».",
		"goal": "Cazar al koloss jefe: en su cuerpo hay clavos del Ministerio.", "foes": {"koloss_adulto": 2, "koloss_jefe": 1},
		"ends": {"ok": {"text": "Matarlo y llevarse los clavos"}}},
	"regreso": {"act": 2, "kind": "side", "title": "Un muerto que camina", "giver": "kelsier", "place": "taller", "needs": ["jefe"],
		"learn": ["banda"], "heard": "Al volver al sótano hay alguien sentado a la mesa.",
		"goal": "Vuelve Kelsier, a quien la banda daba por muerto, con un plan propio.", "foes": {},
		"ends": {"seguirlo": {"text": "Seguir su plan", "sets": ["aliado_kelsier"]}, "rechazar": {"text": "Seguir sin él: usa a la gente", "sets": ["kelsier_rival"]}}},
	"ejercito_koloss": {"act": 2, "kind": "main", "spine": 5, "title": "La Puerta Este", "giver": "ham", "backup": "clubs", "place": "puerta_este", "needs": ["jefe"],
		"learn": ["banda", "rumor"], "heard": "Campanas en toda la ciudad, y Ham: «Ya están acá».",
		"goal": "Llega el ejército koloss. Aguantar la puerta.", "foes": {"koloss_joven": 14, "koloss_adulto": 6, "koloss_jefe": 1},
		"ends": {"ok": {"text": "Aguantar"}}},
	"cuartel": {"act": 2, "kind": "main", "spine": 6, "title": "El ejército que no sale", "giver": "dockson", "backup": "clubs", "place": "cuartel_sur", "needs": ["ejercito_koloss"],
		"learn": ["banda"], "heard": "Dockson: «Mil soldados miraron cómo ardía el este. ¿Por qué?».",
		"goal": "Averiguar por qué no salieron y dejarlos sin armas.", "foes": {"soldado": 12},
		"ends": {"sabotaje": {"text": "Quemar la armería de noche", "sets": ["sin_armeria"]}, "frontal": {"text": "Entrar por el portón"}}},
	"mataneblinos": {"act": 2, "kind": "main", "spine": 6, "title": "Los que pelean sin metal", "giver": "ham", "backup": "clubs", "place": "bosque", "needs": ["ejercito_koloss"],
		"learn": ["banda", "rumor"], "heard": "Ham: «Cazan alománticos, y tu acero no les hace nada».",
		"goal": "Una compañía de mataneblinos: madera y obsidiana.", "teaches": "Pelear sin agarrar metal", "foes": {"mataneblino": 10},
		"ends": {"aprender": {"text": "Atrapar al capitán y aprender su equipo", "sets": ["armadura_madera"]}, "aplastar": {"text": "Acabar con todos"}}},
	"brumosos": {"act": 2, "kind": "main", "spine": 6, "title": "Los perros del Ministerio", "giver": "breeze", "backup": "clubs", "place": "cuartel_sur", "needs": ["ejercito_koloss"],
		"learn": ["banda"], "heard": "Breeze: «El Ministerio contrató a los nuestros».",
		"goal": "Un escuadrón de brumosos: violentos y lanzamonedas.", "foes": {"violento": 4, "lanzamonedas": 4},
		"ends": {"ok": {"text": "Romper el escuadrón"}}},
	"banda_forja": {"act": 2, "kind": "side", "title": "Gente como ustedes", "giver": "breeze", "place": "forja", "needs": ["rastros"],
		"learn": ["rumor"], "heard": "En la Forja: «Hay que pagarles para que no te rompan el taller».",
		"goal": "Una banda de brumosos cobra protección en la Forja.", "foes": {"violento": 3, "lanzamonedas": 2},
		"ends": {"sumar": {"text": "Vencer a su jefa y sumarlos", "sets": ["brumosos_aliados"]}, "romper": {"text": "Romper la banda"}},
		"late": [{"after": 6, "warn": "Vieron a la jefa de la Forja hablando con un obligador.", "text": "Se pasan al Ministerio y aparecen en la procesión.", "lost": true, "sets": ["brumosos_enemigos"]}]},
	"pista_libros": {"act": 2, "kind": "side", "title": "Las cuentas no dan", "giver": "clubs", "place": "taller", "needs": ["rastros"],
		"learn": ["npc"], "heard": "Clubs, al pasar: «Alguien de acá sabía lo de la Puerta antes que nosotros».",
		"goal": "Primera pista del kandra: revisar quién supo qué.", "foes": {},
		"ends": {"ok": {"text": "Anotarlo en el cuaderno", "sets": ["pista_kandra_1"]}}},
	"pista_huesos": {"act": 2, "kind": "side", "title": "Huesos limpios", "giver": "", "place": "darsena", "needs": ["jefe"],
		"learn": ["lugar", "rumor"], "heard": "En el puerto: «Encontraron un esqueleto sin una sola marca».",
		"goal": "Segunda pista del kandra: un cuerpo vaciado.", "foes": {"espectro": 2},
		"ends": {"ok": {"text": "Reconocer de quién era", "sets": ["pista_kandra_2"]}}},

	# ---------------------------------------------------------------- Acto 3: de dónde salen los clavos
	"clavos": {"act": 3, "kind": "main", "spine": 7, "title": "Clavos", "giver": "terrisano", "backup": "clubs", "place": "taller", "needs": ["cuartel", "mataneblinos", "brumosos"],
		"learn": ["banda"], "heard": "Sazed pide a todos en el sótano.",
		"goal": "Sazed reconoce los clavos: el Ministerio hace a los koloss y los suelta cuando quiere castigar.", "foes": {},
		"ends": {"ok": {"text": "Ir contra el Ministerio"}}},
	"plaza": {"act": 3, "kind": "main", "spine": 7, "title": "Ejecuciones en la plaza", "giver": "terrisano", "backup": "clubs", "place": "plaza", "needs": ["clavos"],
		"learn": ["rumor", "banda"], "heard": "Pregoneros en toda la ciudad: habrá ejecuciones en la plaza.",
		"goal": "Los obligadores van a ejecutar a un grupo de skaa.", "foes": {"obligador": 5, "soldado": 8},
		"ends": {"rescatar": {"text": "Atacar y rescatarlos", "sets": ["skaa_plaza"]}, "esperar": {"text": "No delatarse y seguir a los obligadores", "sets": ["pista_ministerio"]}}},
	"marsh": {"act": 3, "kind": "main", "spine": 7, "title": "Un obligador que no parpadea", "giver": "marsh", "backup": "terrisano", "place": "ministerio", "needs": ["clavos"],
		"learn": ["banda"], "heard": "Una nota sin firma: «Hay uno de los suyos adentro».",
		"goal": "Entrar al Ministerio y encontrar al infiltrado. Ofrece una entrada por abajo de Kredik Shaw.", "foes": {"obligador": 4},
		"ends": {"confiar": {"text": "Confiar en él", "sets": ["aliado_marsh"]}, "desconfiar": {"text": "Robarle los planos y seguir sin él", "sets": ["planos_kredik"]}}},
	"yomen": {"act": 3, "kind": "side", "title": "Un obligador que manda", "giver": "yomen", "place": "ministerio", "needs": ["clavos"],
		"learn": ["rumor"], "heard": "Llegó de otra ciudad un obligador que gobierna, y no todos lo quieren acá.",
		"goal": "Yomen vino a Luthadel a pedir cuentas por los koloss.", "foes": {"obligador": 2},
		"ends": {"convencer": {"text": "Mostrarle los clavos", "sets": ["yomen_rompe"]}, "denunciar": {"text": "Delatarlo para ganar tiempo"}}},
	"inquisidor": {"act": 3, "kind": "main", "spine": 8, "title": "El que los huele", "giver": "spook", "backup": "ham", "place": "mercado", "needs": ["plaza", "marsh"],
		"learn": ["banda", "lugar"], "heard": "Spook: «Te viene siguiendo. No es un hombre».",
		"goal": "Un inquisidor los caza. Pelearlo y verlo levantarse.", "foes": {"inquisidor": 1},
		"ends": {"ok": {"text": "Matarlo y quedarse con sus clavos"}}},
	"procesion": {"act": 3, "kind": "main", "spine": 9, "title": "La procesión", "giver": "ham", "backup": "clubs", "place": "asamblea", "needs": ["inquisidor"],
		"learn": ["banda", "rumor"], "heard": "Toda la avenida cerrada: pasa la escolta.",
		"goal": "Obligadores y guerreros mezclados cruzan la avenida con lo que el Ministerio guarda.", "foes": {"obligador": 4, "soldado": 10, "lanzamonedas": 2},
		"ends": {"ok": {"text": "Romper la escolta"}}},
	"convencer_tindwyl": {"act": 3, "kind": "side", "title": "Una terrisana que no perdona", "giver": "tindwyl", "place": "taller", "needs": ["clavos", "mensajero_muerto"],
		"learn": ["npc"], "heard": "Sazed: «Tindwyl no quiere verlos. Hay que ganárselo».",
		"goal": "Solo si murió el mensajero: recuperar sus papeles en el bosque.", "foes": {"espectro": 8, "koloss_adulto": 1},
		"ends": {"ok": {"text": "Devolverlos", "sets": ["amigo_terris"]}}},
	"archivo": {"act": 3, "kind": "side", "title": "Lo que recuerda un terrisano", "giver": "terrisano", "place": "montes", "needs": ["clavos", "amigo_terris"],
		"learn": ["npc"], "heard": "Sazed: «El mensajero traía un camino. Lleva a unas ruinas».",
		"goal": "El Lord Legislador se cura con una reserva escondida.", "foes": {"espectro": 8, "inquisidor": 1},
		"ends": {"ok": {"text": "Saber dónde está la reserva", "sets": ["sabe_reserva"]}}},

	# ---------------------------------------------------------------- Acto 4: quién paga
	"baile": {"act": 4, "kind": "main", "spine": 10, "title": "Un baile en Casa Venture", "giver": "breeze", "backup": "dockson", "place": "venture", "needs": ["procesion"],
		"learn": ["banda"], "heard": "Breeze trae invitaciones que no deberían existir.",
		"goal": "Las casas le compran atium al Ministerio. Entrar disfrazados y escuchar. Conocen a Elend.", "foes": {},
		"ends": {"ok": {"text": "Salir con nombres"}}},
	"hastings": {"act": 4, "kind": "main", "spine": 10, "title": "Los libros de Hastings", "giver": "dockson", "backup": "breeze", "place": "hastings", "needs": ["baile"],
		"learn": ["banda"], "heard": "Dockson: «Hastings paga por los koloss. Está en sus libros».",
		"goal": "Lord Hastings paga por los koloss para arruinar a sus rivales.", "foes": {"guardia_casa": 10},
		"ends": {"chantaje": {"text": "Chantajearlo: abre una puerta de atrás", "sets": ["hastings_comprado"]}, "quemar": {"text": "Quemar la casa"}}},
	"lorch": {"act": 4, "kind": "main", "spine": 10, "title": "La guerra de los Lorch", "giver": "dockson", "backup": "breeze", "place": "lorch", "needs": ["baile"],
		"learn": ["banda"], "heard": "Dockson: «Sin los Lorch, nadie cubre a los demás».",
		"goal": "Asaltar a Casa Lorch, con sus guardias y su brumoso.", "foes": {"guardia_casa": 10, "violento": 1},
		"ends": {"ok": {"text": "Dejarla sin ejército"}}},
	"venture_elend": {"act": 4, "kind": "side", "title": "El heredero", "giver": "elend", "place": "venture", "needs": ["baile"],
		"learn": ["npc"], "heard": "Elend, en el baile: «Búsquenme. Mi padre no es la única opción».",
		"goal": "Elend quiere frenar a su padre desde adentro.", "foes": {"guardia_casa": 6},
		"ends": {"ayudar": {"text": "Ayudarlo a tomar la casa", "sets": ["aliado_elend"], "locks": ["venture_asalto", "straff"]}}},
	"venture_asalto": {"act": 4, "kind": "side", "title": "Ningún Venture", "giver": "kelsier", "place": "venture", "needs": ["baile", "aliado_kelsier"],
		"learn": ["npc"], "heard": "Kelsier: «No hay nobles buenos».",
		"goal": "Tomar la mansión por la fuerza.", "foes": {"guardia_casa": 14, "mistborn": 1},
		"ends": {"tomar": {"text": "Tomarla", "locks": ["venture_elend", "straff"]}}},
	"straff": {"act": 4, "kind": "side", "title": "Una oferta de Straff", "giver": "straff", "place": "venture", "needs": ["baile"],
		"learn": ["npc"], "heard": "Una carta con el sello de Venture.",
		"goal": "Straff quiere comprar a la banda.", "foes": {},
		"ends": {"aceptar": {"text": "Aceptar y traicionarlo más tarde", "sets": ["hastings_comprado"], "locks": ["venture_elend", "venture_asalto"]},
			"rechazar": {"text": "Rechazarlo: manda a su Mistborn", "sets": ["cazador_straff"]}}},
	"cett": {"act": 4, "kind": "side", "title": "Un señor de visita", "giver": "cett", "place": "asamblea", "needs": ["baile"],
		"learn": ["rumor"], "heard": "En la Asamblea: «Cett trajo más soldados de los que dijo».",
		"goal": "Cett busca qué sacar del caos.", "foes": {"soldado": 6},
		"ends": {"pacto": {"text": "Pactar: sus soldados contra los refuerzos", "sets": ["soldados_cett"]}, "echarlo": {"text": "Echarlo de la ciudad"}},
		"late": [{"after": 11, "warn": "Cett está levantando el campamento.", "text": "Cett se va y sus soldados quedan fuera.", "lost": true}]},
	"pista_voz": {"act": 4, "kind": "side", "title": "No sos vos", "giver": "", "place": "taller", "needs": ["baile", "pista_kandra_1", "pista_kandra_2"],
		"learn": ["lugar"], "heard": "Con las dos primeras pistas, el cuaderno señala a alguien de la mesa.",
		"goal": "Tercera pista del kandra: hacerle una pregunta que solo el verdadero sabe.", "foes": {},
		"ends": {"ok": {"text": "Confirmarlo", "sets": ["pista_kandra_3"]}}},
	"kandra": {"act": 4, "kind": "side", "title": "Lo que se sienta a la mesa", "giver": "kandra", "place": "taller", "needs": ["pista_kandra_3"],
		"learn": ["npc"], "heard": "Con las tres pistas, se lo puede enfrentar.",
		"goal": "Enfrentar al kandra. Reemplazó a Dockson, Breeze o Spook, según la partida.", "foes": {"kandra": 1},
		"ends": {"matar": {"text": "Matarlo"}, "usar": {"text": "Usarlo para filtrar mentiras", "sets": ["secreto_koloss"]}, "contrato": {"text": "Comprarle el contrato: se suma a la banda", "sets": ["kandra_aliado"]}},
		"late": [{"after": 8, "warn": "El Ministerio sabe demasiado sobre el sótano.", "text": "Allanan el taller: Clubs cae y la base pasa a la Dársena.", "sets": ["taller_perdido"]},
			{"after": 11, "warn": "Alguien de la mesa no vino hoy.", "text": "El kandra entrega al grupo, y el último tramo arranca emboscado.", "lost": true, "sets": ["emboscada_kandra"]}]},
	"cazadores": {"act": 4, "kind": "main", "spine": 11, "title": "Los que pelean de noche", "giver": "spook", "backup": "ham", "place": "barrio_skaa", "needs": ["hastings", "lorch"],
		"learn": ["banda", "lugar"], "heard": "Alguien vuela sobre el barrio, y Spook avisa: «No son de los nuestros».",
		"goal": "Las casas mandan a sus Mistborn contra la banda, sobre los tejados, en la bruma.", "foes": {"mistborn": 3},
		"ends": {"ok": {"text": "Vencerlos"}}},
	"vin": {"act": 4, "kind": "side", "title": "La de los tejados", "giver": "vin", "place": "barrio_skaa", "needs": ["cazadores"],
		"learn": ["lugar"], "heard": "Una figura los mira desde el tejado, noche tras noche.",
		"goal": "Una Mistborn sin casa los viene siguiendo, y los prueba a duelo.", "foes": {"vin": 1},
		"ends": {"sumar": {"text": "Ganarle y ofrecerle la banda", "sets": ["aliada_vin"]}, "rival": {"text": "Ganarle y dejarla ir"}}},
	"reserva": {"act": 4, "kind": "side", "title": "La reserva", "giver": "terrisano", "place": "kredik", "needs": ["sabe_reserva"],
		"learn": ["npc"], "heard": "Sazed: «Hay un camino por los subniveles. Cruza la bruma solo por ahí».",
		"goal": "Bajar a los subniveles y vaciar lo que cura al Lord Legislador.", "foes": {"inquisidor": 2, "obligador": 4},
		"ends": {"ok": {"text": "Vaciarla", "sets": ["secreto_reserva"]}}},

	# ---------------------------------------------------------------- Acto 5: se entra por un solo lado, según lo que hicieron
	"f_levantamiento": {"act": 5, "kind": "main", "spine": 12, "title": "El barrio se levanta", "giver": "terrisano", "backup": "clubs", "place": "barrio_skaa", "needs": ["cazadores"],
		"any": [2, ["skaa_corrales", "skaa_aldea", "skaa_plaza"]],
		"learn": ["npc"], "heard": "Los skaa que salvaron los buscan en la calle.",
		"goal": "Los skaa marchan a la rampa: un ejército contra otro, y ustedes por el medio.", "foes": {"soldado": 30, "obligador": 6},
		"ends": {"ok": {"text": "Llegar a la Gran Entrada", "locks": ["f_invitado", "f_debajo", "f_fuerza"]}}},
	"f_invitado": {"act": 5, "kind": "main", "spine": 12, "title": "Con invitación", "giver": "elend", "backup": "breeze", "place": "kredik", "needs": ["cazadores", "aliado_elend"],
		"learn": ["npc"], "heard": "Elend: «Casa Venture sube a Kredik Shaw. Vengan conmigo».",
		"goal": "Entrar con la comitiva de Casa Venture, y pelear solo cuando ya es tarde.", "foes": {"inquisidor": 2},
		"ends": {"ok": {"text": "Llegar al trono", "locks": ["f_levantamiento", "f_debajo", "f_fuerza"]}}},
	"f_debajo": {"act": 5, "kind": "main", "spine": 12, "title": "Por abajo", "giver": "marsh", "backup": "terrisano", "place": "kredik", "needs": ["cazadores"],
		"any": [1, ["aliado_marsh", "planos_kredik"]],
		"learn": ["npc"], "heard": "Marsh, o los planos robados: el pozo de los subniveles.",
		"goal": "Subir desde el pozo de los subniveles.", "foes": {"inquisidor": 3, "obligador": 6},
		"ends": {"ok": {"text": "Llegar al trono", "locks": ["f_levantamiento", "f_invitado", "f_fuerza"]}}},
	"f_fuerza": {"act": 5, "kind": "main", "spine": 12, "title": "A los golpes", "giver": "", "place": "kredik", "needs": ["cazadores"],
		"learn": ["banda"], "heard": "Siempre disponible: el camino de quien no consiguió otro.",
		"goal": "Subir la rampa, contra todo lo que quede.", "foes": {"soldado": 20, "obligador": 6, "inquisidor": 3},
		"ends": {"ok": {"text": "Llegar al trono", "locks": ["f_levantamiento", "f_invitado", "f_debajo"]}}},
	"f_trono": {"act": 5, "kind": "main", "spine": 12, "title": "El Lord Legislador", "giver": "", "place": "kredik", "needs": [],
		"any": [1, ["f_levantamiento", "f_invitado", "f_debajo", "f_fuerza"]],
		"learn": ["lugar"], "heard": "Al abrirse el salón del trono.",
		"goal": "Pelear con él. Llega más débil según lo que hicieron.", "foes": {"lord_ruler": 1},
		"ends": {"matar": {"text": "Matarlo"}}},
}

## La última misión: terminarla es terminar la historia.
const LAST := "f_trono"


## Las misiones que se pueden empezar ahora. `done` y `locked` son diccionarios usados como conjuntos.
static func available(done: Dictionary, locked: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in QUESTS:
		if id in done or id in locked:
			continue
		var q: Dictionary = QUESTS[id]
		if not (q["needs"] as Array).all(func(n: String) -> bool: return n in done):
			continue
		if q.has("any") and (q["any"][1] as Array).filter(func(n: String) -> bool: return n in done).size() < q["any"][0]:
			continue
		out.append(id)
	return out


## Termina una misión con uno de sus finales: la marca como hecha, deja sus marcas, bloquea lo que corresponda y aplica
## las consecuencias de lo que quedó sin hacer.
static func finish(id: String, ending: String, done: Dictionary, locked: Dictionary) -> void:
	var e: Dictionary = QUESTS[id]["ends"][ending]
	done[id] = true
	for flag: String in e.get("sets", []):
		done[flag] = true
	for other: String in e.get("locks", []):
		locked[other] = true
	var mains := 0
	for spine in range(1, 13):
		mains += 1 if _spine_done(spine, done) else 0
	for other: String in QUESTS:
		if other in done or other in locked:
			continue
		for late: Dictionary in QUESTS[other].get("late", []):
			if mains >= late["after"]:
				for flag: String in late.get("sets", []):
					done[flag] = true
				if late.get("lost", false):
					locked[other] = true


## Un número de la columna cuenta cuando se hicieron todas sus misiones (del final alcanza con la última).
static func _spine_done(spine: int, done: Dictionary) -> bool:
	if spine == 12:
		return LAST in done
	for id: String in QUESTS:
		if QUESTS[id].get("spine", 0) == spine and not id in done:
			return false
	return true
