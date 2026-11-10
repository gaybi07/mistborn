class_name Dialogues
## Conversaciones de los NPC de la historia (ver DialogueBox). Por NPC (clave de Story.NPCS):
##   "entries": [[condición, nodo], ...]: se arranca en el primer nodo cuya condición se cumple.
##   "nodes": nodo -> {"text", "options": [{"text", "to" (otro nodo; sin "to" se cierra), "do": [acciones]}]}.
## Condiciones: {} siempre; {"active": id, "step": n} misión en curso en ese paso; {"done": id}; {"available": id}.
## Acciones: ["start", id], ["advance", id], ["finish", id, final], ["learn", texto].
## Jugando solo se habla en singular (ver docs/HISTORIA.md).

const LINES := {
	"dockson": {
		"entries": [
			[{"done": "prueba_plaza"}, "despues"],
			[{"active": "prueba_plaza", "step": 1}, "vuelta"],
			[{"active": "prueba_plaza", "step": 0}, "esperando"],
			[{}, "inicio"],
		],
		"nodes": {
			"inicio": {"text": "Colgaron un cartel nuevo en la Plaza Central y nadie de acá sabe leer bien. ¿Te das una vuelta y me contás qué dice?",
				"options": [
					{"text": "Voy.", "do": [["start", "prueba_plaza"]], "to": "gracias"},
					{"text": "¿Por qué no vas vos?", "to": "porque"},
					{"text": "Ahora no.", "to": ""},
				]},
			"porque": {"text": "Porque a mí me conocen los obligadores de la plaza. A vos todavía no.",
				"options": [
					{"text": "Está bien, voy.", "do": [["start", "prueba_plaza"]], "to": "gracias"},
					{"text": "Otro día.", "to": ""},
				]},
			"gracias": {"text": "Bien. Está pegado cerca de la fuente. No te quedes mirándolo mucho.", "options": [{"text": "Hasta luego."}]},
			"esperando": {"text": "¿Y? ¿Ya fuiste a la plaza?", "options": [{"text": "Todavía no."}]},
			"vuelta": {"text": "¿Qué decía el cartel?",
				"options": [
					{"text": "Que el Ministerio busca brumosos. Pagan por nombres.", "do": [["learn", "El Ministerio paga por nombres de brumosos (cartel de la Plaza Central)."], ["finish", "prueba_plaza", "verdad"]], "to": "fin_verdad"},
					{"text": "Nada importante.", "do": [["finish", "prueba_plaza", "mentira"]], "to": "fin_mentira"},
				]},
			"fin_verdad": {"text": "Pagan por nombres... Entonces hay que cuidar a quién le hablamos. Gracias.", "options": [{"text": "De nada."}]},
			"fin_mentira": {"text": "Mm. Si no era nada, no lo habrían puesto ahí. En fin.", "options": [{"text": "Adiós."}]},
			"despues": {"text": "Ya me ayudaste con el cartel. Por ahora no tengo nada más.", "options": [{"text": "Adiós."}]},
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
	if cond.has("available") and not cond["available"] in Story.available(QuestLog.done, QuestLog.locked):
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
