class_name Allomancy
extends Node
## Reservas de metales y su estado (apagado / quemando / avivando).
## Cada habilidad consulta strength(metal): 0 apagado, 1 quemando, FLARE_STRENGTH avivando.

enum State { OFF, BURN, FLARE }

const FLARE_STRENGTH := 2.0

## label, tecla, color, reserva máxima, consumo por segundo al quemar y al avivar.
## Tocar la tecla enciende/apaga; doble toque y mantener aviva mientras se mantenga.
## El orden es el de la barra del HUD: 1-4 los de combate, Z X C V B los demás.
## Ritmos: pasivos casi permanentes (5-7 min), de combate ~100 s (20-25 s avivando), atium escaso.
const METALS := {
	&"steel": {"label": "Acero", "key": KEY_1, "color": Color(0.35, 0.6, 1.0), "max": 100.0, "burn": 1.0, "flare": 5.0},
	&"iron": {"label": "Hierro", "key": KEY_2, "color": Color(0.62, 0.66, 0.75), "max": 100.0, "burn": 1.0, "flare": 5.0},
	&"pewter": {"label": "Peltre", "key": KEY_3, "color": Color(0.95, 0.55, 0.25), "max": 100.0, "burn": 1.5, "flare": 6.0},
	&"atium": {"label": "Atium", "key": KEY_4, "color": Color(1.0, 0.95, 0.8), "max": 30.0, "burn": 2.0, "flare": 4.0},
	&"zinc": {"label": "Cinc", "key": KEY_Z, "color": Color(0.85, 0.35, 0.3), "max": 100.0, "burn": 1.0, "flare": 4.0},
	&"copper": {"label": "Cobre", "key": KEY_X, "color": Color(0.78, 0.47, 0.3), "max": 100.0, "burn": 0.25, "flare": 1.6},
	&"bronze": {"label": "Bronce", "key": KEY_C, "color": Color(0.85, 0.65, 0.35), "max": 100.0, "burn": 0.25, "flare": 1.6},
	&"tin": {"label": "Estaño", "key": KEY_V, "color": Color(0.82, 0.86, 0.7), "max": 100.0, "burn": 0.33, "flare": 1.6},
	&"brass": {"label": "Latón", "key": KEY_B, "color": Color(0.55, 0.75, 0.6), "max": 100.0, "burn": 1.0, "flare": 4.0},
}

var reserve: Dictionary = {}
var state: Dictionary = {}
## Aplacado por el latón de otro: no puedes avivar (lo avivado baja a quemar).
var flare_blocked := false:
	set(v):
		flare_blocked = v
		if v:
			for m in METALS:
				if state.get(m) == State.FLARE:
					state[m] = State.BURN


func _ready() -> void:
	for m in METALS:
		reserve[m] = METALS[m]["max"]
		state[m] = State.OFF


func _process(delta: float) -> void:
	# Consumo en tiempo real: el atium avivado ralentiza el mundo, no al alomántico.
	var real_delta := delta / Engine.time_scale
	for m in METALS:
		if state[m] == State.OFF:
			continue
		var rate: float = METALS[m]["flare"] if state[m] == State.FLARE else METALS[m]["burn"]
		reserve[m] = maxf(reserve[m] - rate * real_delta, 0.0)
		if reserve[m] <= 0.0:
			state[m] = State.OFF


func set_state(metal: StringName, new_state: State) -> void:
	if new_state != State.OFF and reserve[metal] <= 0.0:
		new_state = State.OFF
	if new_state == State.FLARE and flare_blocked:
		new_state = State.BURN
	state[metal] = new_state


## Metales que se manejan con la tecla `key` (cada tecla es un metal).
static func metals_for_key(key: Key) -> Array[StringName]:
	var out: Array[StringName] = []
	for m in METALS:
		if METALS[m]["key"] == key:
			out.append(m)
	return out


func toggle_burn(metal: StringName) -> void:
	set_state(metal, State.OFF if state[metal] != State.OFF else State.BURN)


func toggle_flare(metal: StringName) -> void:
	set_state(metal, State.BURN if state[metal] == State.FLARE else State.FLARE)


func stop_all() -> void:
	for m in METALS:
		state[m] = State.OFF


func refill(metal: StringName, amount: float) -> void:
	reserve[metal] = minf(reserve[metal] + amount, METALS[metal]["max"])


func burning_metals() -> Array[StringName]:
	var out: Array[StringName] = []
	for m in METALS:
		if state[m] != State.OFF:
			out.append(m)
	return out


func is_burning(metal: StringName) -> bool:
	return state[metal] != State.OFF


func is_flaring(metal: StringName) -> bool:
	return state[metal] == State.FLARE


func strength(metal: StringName) -> float:
	match state[metal]:
		State.BURN:
			return 1.0
		State.FLARE:
			return FLARE_STRENGTH
	return 0.0
