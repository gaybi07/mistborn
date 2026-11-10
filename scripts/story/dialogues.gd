class_name Dialogues
## Conversaciones de los NPC de la historia (ver DialogueBox). Por NPC (clave de Story.NPCS):
##   "entries": [[condición, nodo], ...]: se arranca en el primer nodo cuya condición se cumple.
##   "nodes": nodo -> {"text", "options": [{"text", "to" (otro nodo; sin "to" se cierra), "do": [acciones]}]}.
## Condiciones: {} siempre; {"active": id, "step": n} misión en curso en ese paso; {"done": id}; {"available": id}.
## Acciones: ["start", id], ["advance", id], ["finish", id, final], ["learn", texto], ["read", cartel].
## Los carteles (QuestLog.SIGNS) también van acá, con su "name".
## Jugando solo se habla en singular (ver docs/HISTORIA.md).

const LINES := {
	# Carteles (QuestLog.SIGNS): "name" es lo que sale arriba de la caja.
	"cartel_plaza": {
		"name": "Cartel del Ministerio de Acero",
		"entries": [[{}, "leer"]],
		"nodes": {
			"leer": {"text": "Por orden del Ministerio de Acero: se pagará en oro a quien entregue el nombre de un brumoso, " +
					"skaa mestizo o alomántico oculto. Presentarse ante cualquier obligador. Esconder a uno se paga con el foso.",
				"options": [{"text": "Dejar de leer.", "do": [["read", "cartel_plaza"]]}]},
		},
	},
	# ---------------------------------------------------------------- Acto 1: narraciones (misiones sin quien las dé)
	"narra_tejados": {
		"name": "Sobre los tejados",
		"entries": [[{"active": "tejados", "step": 1}, "n"]],
		"nodes": {
			"n": {"text": "Una patrulla te persigue entre los techos del barrio skaa. Saltás de canaleta en canaleta, frenás al que se acerca demasiado... y al final, en un callejón sin salida, te agarran igual.",
				"options": [{"text": "(Dejar que te lleven.)", "do": [["finish", "tejados", "ok"]]}]},
		},
	},
	"narra_foso": {
		"name": "El foso de ceniza",
		"entries": [[{"active": "foso", "step": 1}, "n"]],
		"nodes": {
			"n": {"text": "Despertás encadenado en el fondo del foso. El capataz grita los números de la cuadrilla y las palas no paran. Esa noche la cadena cede. Cuando corrés hacia la rampa, un preso herido te agarra del tobillo: «No me dejes acá».",
				"options": [
					{"text": "Cargarlo y sacarlo con vos.", "do": [["finish", "foso", "salvar"]]},
					{"text": "Soltarte: no llegan los dos.", "do": [["finish", "foso", "dejar"]]},
				]},
		},
	},
	"narra_afueras": {
		"name": "Lo que hay de noche",
		"entries": [[{"active": "afueras", "step": 1}, "n"]],
		"nodes": {
			"n": {"text": "La bruma tapa el camino. Algo pálido se arrastra entre los troncos y, más lejos, se oyen pasos enormes: koloss. Caminás hacia las luces de Luthadel hasta que un hombre alto, con las orejas llenas de aros, te corta el paso. «Usted no debería estar vivo», dice. «Venga conmigo.»",
				"options": [{"text": "Seguirlo.", "do": [["learn", "Sazed, un terrisano, te encontró en las afueras y te trajo a Luthadel."], ["finish", "afueras", "ok"]]}]},
		},
	},
	"narra_guardian_bosque": {
		"name": "El guardián del bosque",
		"entries": [[{"active": "guardian_bosque", "step": 1}, "n"]],
		"nodes": {
			"n": {"text": "Entre los árboles muertos hay un koloss adulto, solo, más grande que cualquiera que hayas visto. No ruge: te mira y espera.",
				"options": [{"text": "Pelear hasta tumbarlo.", "do": [["finish", "guardian_bosque", "ok"]]}]},
		},
	},
	# ---------------------------------------------------------------- Acto 1: la banda (en el taller) y los de afuera
	"terrisano": {
		"entries": [
			[{"active": "el_taller", "step": 1}, "vuelta"],
			[{"active": "el_taller", "step": 0}, "espera"],
			[{"available": "el_taller"}, "ofrece"],
			[{}, "suelto"],
		],
		"nodes": {
			"ofrece": {"text": "Luthadel no es lugar para alguien que acaba de escaparse del foso. Conozco a un carpintero, Clubs, que no hace preguntas. Usted le interesa.",
				"options": [
					{"text": "Llevame con él.", "do": [["start", "el_taller"]], "to": "va"},
					{"text": "¿Por qué le intereso?", "to": "porque"},
					{"text": "Todavía no.", "to": ""},
				]},
			"porque": {"text": "Porque sobrevivió a la bruma. Casi nadie lo hace, salvo los que tienen metales en la sangre.",
				"options": [
					{"text": "Entonces vamos.", "do": [["start", "el_taller"]], "to": "va"},
					{"text": "Lo pienso.", "to": ""},
				]},
			"va": {"text": "El taller está acá nomás, con la puerta grande. Entre: Clubs lo espera adentro.", "options": [{"text": "Voy."}]},
			"espera": {"text": "El taller es el de la puerta grande. Clubs no espera dos veces.", "options": [{"text": "Ya voy."}]},
			"vuelta": {"text": "¿Y? ¿Qué le dijo Clubs?",
				"options": [{"text": "Me explicó lo que soy. Ya elegí un camino.", "do": [["learn", "Sos alomántico: quemás metales. Clubs y su banda te enseñan."], ["finish", "el_taller", "ok"]], "to": "fin"}]},
			"fin": {"text": "Entonces empieza lo difícil. Los demás de la banda tienen cosas para enseñarle. Hable con ellos.", "options": [{"text": "Gracias, Sazed."}]},
			"suelto": {"text": "Hay tanto que el Lord Legislador quiere que olvidemos. Yo prefiero recordar.", "options": [{"text": "Adiós."}]},
		},
	},
	"clubs": {
		"entries": [
			[{"active": "t_sigiloso", "step": 1}, "sig_vuelta"],
			[{"active": "t_volador", "step": 1}, "vol_vuelta"],
			[{"active": "t_sigiloso", "step": 0}, "sig_espera"],
			[{"active": "t_volador", "step": 0}, "vol_espera"],
			[{"available": "t_sigiloso"}, "sig_ofrece"],
			[{"available": "t_volador"}, "vol_ofrece"],
			[{}, "suelto"],
		],
		"nodes": {
			"sig_ofrece": {"text": "Si no querés que te encuentren, vení conmigo. El barrio skaa de noche es la mejor escuela: cruzalo sin que un buscador te huela.",
				"options": [
					{"text": "Vamos.", "do": [["start", "t_sigiloso"]], "to": "sig_va"},
					{"text": "¿Buscador?", "to": "sig_buscador"},
					{"text": "Después.", "to": ""},
				]},
			"sig_buscador": {"text": "Gente que siente cuando quemás metal, como un tambor. Para eso está el cobre: te tapa.",
				"options": [
					{"text": "Entonces vamos.", "do": [["start", "t_sigiloso"]], "to": "sig_va"},
					{"text": "Después.", "to": ""},
				]},
			"sig_va": {"text": "El barrio skaa está al sur. Cruzalo y volvé entero.", "options": [{"text": "Voy."}]},
			"sig_espera": {"text": "¿Todavía acá? El barrio skaa está al sur.", "options": [{"text": "Ya voy."}]},
			"sig_vuelta": {"text": "¿Llegaste al otro lado?",
				"options": [{"text": "Sin que me vieran.", "do": [["finish", "t_sigiloso", "ok"]], "to": "sig_fin"}]},
			"sig_fin": {"text": "Bien. El cobre te tapa, el estaño te avisa. No te olvides de ninguno de los dos.", "options": [{"text": "No me olvido."}]},
			"vol_ofrece": {"text": "Spook anda por los tejados y no baja ni a comer. Si querés volar, abajo hay una pista de saltos. Hacela y te lo presento.",
				"options": [
					{"text": "Bajo.", "do": [["start", "t_volador"]], "to": "vol_va"},
					{"text": "Después.", "to": ""},
				]},
			"vol_va": {"text": "La pista está en el sótano. Empujá con el acero, tirá con el hierro, y no mires para abajo.", "options": [{"text": "Voy."}]},
			"vol_espera": {"text": "La pista te espera abajo, en el sótano.", "options": [{"text": "Ya voy."}]},
			"vol_vuelta": {"text": "¿Te caíste mucho?",
				"options": [{"text": "Algunas veces. Pero llegué.", "do": [["finish", "t_volador", "ok"]], "to": "vol_fin"}]},
			"vol_fin": {"text": "Así se aprende el acero: empujando hasta que el piso deja de ser un problema.", "options": [{"text": "Adiós."}]},
			"suelto": {"text": "Esto es un taller, no una posada. Si no venís a trabajar, no estorbes.", "options": [{"text": "Perdón."}]},
		},
	},
	"ham": {
		"entries": [
			[{"active": "t_peleador", "step": 1}, "vuelta"],
			[{"active": "t_peleador", "step": 0}, "espera"],
			[{"available": "t_peleador"}, "ofrece"],
			[{}, "suelto"],
		],
		"nodes": {
			"ofrece": {"text": "¡Al fin alguien nuevo! Abajo tengo una sala para pegarle a cosas que devuelven los golpes. Aguantá las oleadas y te enseño a quemar peltre como se debe.",
				"options": [
					{"text": "Bajemos.", "do": [["start", "t_peleador"]], "to": "va"},
					{"text": "¿Para qué sirve el peltre?", "to": "peltre"},
					{"text": "Otro día.", "to": ""},
				]},
			"peltre": {"text": "Te hace más fuerte, más rápido, y te deja seguir parado cuando deberías estar en el piso. Ahora, ¿seguís siendo vos si el metal te sostiene? Eso me lo pregunto seguido.",
				"options": [
					{"text": "Bajemos.", "do": [["start", "t_peleador"]], "to": "va"},
					{"text": "Otro día.", "to": ""},
				]},
			"va": {"text": "La sala de combate está en el sótano. Cuando termines, subí y contame.", "options": [{"text": "Voy."}]},
			"espera": {"text": "La sala está abajo. Los koloss de práctica no se van a cansar solos.", "options": [{"text": "Ya voy."}]},
			"vuelta": {"text": "¿Cuántas oleadas aguantaste?",
				"options": [{"text": "Todas.", "do": [["finish", "t_peleador", "ok"]], "to": "fin"}]},
			"fin": {"text": "Eso es peltre. La próxima, más pesadas.", "options": [{"text": "Dale."}]},
			"suelto": {"text": "¿Sabés qué es lo que más me gusta de pelear? Que después se piensa mejor.", "options": [{"text": "Adiós, Ham."}]},
		},
	},
	"breeze": {
		"entries": [
			[{"active": "t_manipulador", "step": 1}, "vuelta"],
			[{"active": "t_manipulador", "step": 0}, "espera"],
			[{"available": "t_manipulador"}, "ofrece"],
			[{}, "suelto"],
		],
		"nodes": {
			"ofrece": {"text": "Querido, la fuerza bruta es para Ham. Lo elegante es que la gente quiera lo que vos querés. Andá al mercado y probá: calmalos o encendelos, lo que más te divierta.",
				"options": [
					{"text": "Voy al mercado.", "do": [["start", "t_manipulador"]], "to": "va"},
					{"text": "Después.", "to": ""},
				]},
			"va": {"text": "El mercado está al norte de la plaza. Cuidá los bolsillos... los tuyos.", "options": [{"text": "Voy."}]},
			"espera": {"text": "¿El mercado? Al norte de la plaza. No me hagas repetir las cosas, es agotador.", "options": [{"text": "Ya voy."}]},
			"vuelta": {"text": "¿Y? ¿Cómo quedó el mercado?",
				"options": [
					{"text": "Los calmé: nadie salió herido.", "do": [["finish", "t_manipulador", "calmar"]], "to": "fin_calmar"},
					{"text": "Los encendí: hubo botín y vinieron los guardias.", "do": [["finish", "t_manipulador", "encender"]], "to": "fin_encender"},
				]},
			"fin_calmar": {"text": "Prolijo. Aburrido, pero prolijo. El latón te queda bien.", "options": [{"text": "Gracias."}]},
			"fin_encender": {"text": "¡Escandaloso! Me encanta. El cinc es para los que no le temen al ruido.", "options": [{"text": "Gracias."}]},
			"suelto": {"text": "¿Sentís eso? Es tu mal humor desapareciendo. De nada.", "options": [{"text": "Adiós, Breeze."}]},
		},
	},
	"tesa": {
		"entries": [
			[{"done": "tesa_enojada"}, "enojada"],
			[{"active": "corrales", "step": 1}, "vuelta"],
			[{"active": "corrales", "step": 0}, "espera"],
			[{"available": "corrales"}, "ofrece"],
			[{"done": "corrales"}, "despues"],
			[{}, "suelto"],
		],
		"nodes": {
			"ofrece": {"text": "¿Vos sos de los del taller? El capataz de los corrales cobra la deuda con los chicos: se los lleva al carbón y no vuelven. Alguien tiene que hacer algo.",
				"options": [
					{"text": "Me encargo.", "do": [["start", "corrales"]], "to": "va"},
					{"text": "¿Cuánto debe la gente?", "to": "deuda"},
					{"text": "No es asunto mío.", "to": "no"},
				]},
			"deuda": {"text": "Más de lo que van a ganar en la vida. El número lo pone él.",
				"options": [
					{"text": "Me encargo.", "do": [["start", "corrales"]], "to": "va"},
					{"text": "No es asunto mío.", "to": "no"},
				]},
			"no": {"text": "Nunca es asunto de nadie.", "options": [{"text": "..."}]},
			"va": {"text": "Está junto a las pilas de carbón, acá en los corrales. Tiene guardias.", "options": [{"text": "Voy."}]},
			"espera": {"text": "El capataz sigue ahí, junto al carbón. Los chicos también.", "options": [{"text": "Ya voy."}]},
			"vuelta": {"text": "¿Qué pasó con el capataz?",
				"options": [
					{"text": "Lo eché a golpes.", "do": [["finish", "corrales", "pelear"]], "to": "fin_pelear"},
					{"text": "Pagué la deuda.", "do": [["finish", "corrales", "pagar"]], "to": "fin_pagar"},
					{"text": "No me metí: lo que sabe vale más.", "do": [["finish", "corrales", "dato"]], "to": "fin_dato"},
				]},
			"fin_pelear": {"text": "Van a mandar a otro... pero hoy los chicos vuelven a casa.", "options": [{"text": "Cuidalos."}]},
			"fin_pagar": {"text": "Con tu plata. No me lo voy a olvidar.", "options": [{"text": "Cuidalos."}]},
			"fin_dato": {"text": "...Entonces andate. Ya sé de qué lado estás.", "options": [{"text": "..."}]},
			"despues": {"text": "Los corrales están más tranquilos. Por ahora.", "options": [{"text": "Adiós, Tesa."}]},
			"enojada": {"text": "No tengo nada que hablar con vos.", "options": [{"text": "..."}]},
			"suelto": {"text": "Si no venís a ayudar, correte del camino de los carros.", "options": [{"text": "Perdón."}]},
		},
	},
	"dockson": {
		"entries": [
			[{"active": "contrabando", "step": 1}, "vuelta"],
			[{"active": "contrabando", "step": 0}, "espera"],
			[{"available": "contrabando"}, "ofrece"],
			[{}, "suelto"],
		],
		"nodes": {
			"ofrece": {"text": "Tenemos un cargamento atascado en la Dársena: cajas de metales que oficialmente no existen. Si alguien abre una, nosotros tampoco existimos más. Sacalas antes.",
				"options": [
					{"text": "Voy.", "do": [["start", "contrabando"]], "to": "va"},
					{"text": "¿Qué hay en las cajas?", "to": "cajas"},
					{"text": "Después.", "to": ""},
				]},
			"cajas": {"text": "Estaño, peltre, algo de bronce. Lo que llena los frascos de la tienda.",
				"options": [
					{"text": "Voy.", "do": [["start", "contrabando"]], "to": "va"},
					{"text": "Después.", "to": ""},
				]},
			"va": {"text": "La Dársena está al este, sobre el río. Hay soldados revisando: no te hagas ver.", "options": [{"text": "Voy."}]},
			"espera": {"text": "Las cajas siguen en la Dársena, y los soldados también.", "options": [{"text": "Ya voy."}]},
			"vuelta": {"text": "¿Las cajas?",
				"options": [{"text": "Las saqué enteras.", "do": [["finish", "contrabando", "ok"]], "to": "fin"}]},
			"fin": {"text": "Perfecto. La tienda del taller va a tener frascos esta semana.", "options": [{"text": "Bien."}]},
			"suelto": {"text": "Organizo, cuento, reviso. Alguien en esta banda tiene que hacerlo.", "options": [{"text": "Adiós, Dockson."}]},
		},
	},
	"tindwyl": {
		"entries": [
			[{"active": "mensajero", "step": 1}, "vuelta"],
			[{"active": "mensajero", "step": 0}, "espera"],
			[{"available": "mensajero"}, "ofrece"],
			[{}, "suelto"],
		],
		"nodes": {
			"ofrece": {"text": "Mandé a un mensajero por el Bosque Muerto hace tres días. No volvió. Los terrisanos no nos perdemos: algo lo detuvo. Encuéntrelo.",
				"options": [
					{"text": "Lo voy a buscar.", "do": [["start", "mensajero"]], "to": "va"},
					{"text": "¿Qué hay en el bosque?", "to": "bosque"},
					{"text": "No puedo ahora.", "to": ""},
				]},
			"bosque": {"text": "Espectros. Se comen lo que se pierde en la bruma y se quedan con los huesos.",
				"options": [
					{"text": "Lo voy a buscar.", "do": [["start", "mensajero"]], "to": "va"},
					{"text": "No puedo ahora.", "to": ""},
				]},
			"va": {"text": "El bosque está al sudoeste, pasando el camino. Vaya antes de que sea tarde.", "options": [{"text": "Voy."}]},
			"espera": {"text": "Cada día que pasa, mi mensajero tiene menos tiempo.", "options": [{"text": "Ya voy."}]},
			"vuelta": {"text": "¿Lo encontró?",
				"options": [{"text": "Está vivo. Lo traje de vuelta.", "do": [["finish", "mensajero", "ok"]], "to": "fin"}]},
			"fin": {"text": "Le debo una. Los terrisanos no olvidamos las deudas.", "options": [{"text": "No es nada."}]},
			"suelto": {"text": "Una memoria guardada vale más que cien libros quemados.", "options": [{"text": "Adiós, Tindwyl."}]},
		},
	},
}


## Nodo con el que arranca la conversación con ese NPC ("" si no tiene nada que decir).
static func entry(npc: String) -> String:
	for e: Array in LINES.get(npc, {}).get("entries", []):
		if check(e[0]):
			return e[1]
	return ""


static func check(cond: Dictionary) -> bool:
	if cond.has("done") and not QuestLog.done.has(cond["done"]):
		return false
	if cond.has("available") and not cond["available"] in QuestLog.startable():
		return false
	if cond.has("active"):
		if not QuestLog.active.has(cond["active"]):
			return false
		if cond.has("step") and int(QuestLog.active[cond["active"]]) != int(cond["step"]):
			return false
	return true


static func run(actions: Array) -> void:
	for a: Array in actions:
		match a[0]:
			"start":
				QuestLog.start(a[1])
			"advance":
				QuestLog.advance(a[1])
			"finish":
				QuestLog.finish(a[1], a[2])
			"learn":
				QuestLog.learn(a[1])
			"read":
				QuestLog.read(a[1])
