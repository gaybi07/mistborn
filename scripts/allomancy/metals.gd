class_name Metals
## Física y reglas de la alomancia compartidas por el jugador y los PNJ:
## - qué es metal y cuánto pesa (lo anclado no se mueve),
## - empujar / tirar con fuerzas iguales y opuestas (3ª ley de Newton),
## - nubes de cobre (ocultan a los alománticos del bronce).
##
## Objetivos móviles: RigidBody3D, o cualquier nodo con apply_allomantic_impulse() y
## allomantic_mass (PNJ, guardias, el propio jugador si lleva monedas).

const BASE_FORCE := 1800.0  ## Newtons a distancia cero (quemando)
const MAX_TARGET_SPEED := 45.0
const MAX_DV_PER_STEP := 8.0
const COPPER_RADIUS := 12.0  ## radio de la nube de cobre (avivando, el doble)
## Fracción del alcance dentro de la cual la fuerza no baja con la distancia.
const FALLOFF_PLATEAU := 0.35


## Punto al que apuntan las líneas (meta "center_offset" o el origen del nodo).
static func center_of(t: Node3D) -> Vector3:
	if t.has_meta(&"center_offset"):
		return t.global_position + (t.get_meta(&"center_offset") as Vector3)
	return t.global_position


## Masa que se mueve al empujar; 0 si el objeto está anclado.
static func movable_mass(t: Node3D) -> float:
	if t.has_method(&"apply_allomantic_impulse"):
		return t.allomantic_mass
	var rb := t as RigidBody3D
	if rb and not rb.freeze:
		return rb.mass
	return 0.0


## Distancia hasta la que un metal es útil: más masa (o anclado), más alcance.
static func effective_reach(t: Node3D, reach: float) -> float:
	var mass := movable_mass(t)
	if mass <= 0.0:
		mass = 2000.0
	var mass_factor := clampf(log(mass + 1.0) / 7.6, 0.0, 1.0)
	return reach * lerpf(0.4, 0.85, mass_factor)


## Empuja (dir_sign = 1) o tira (dir_sign = -1) de `target` desde `origin`.
## Mueve el objetivo y devuelve la aceleración que recibe quien empuja (de masa user_mass).
static func push_pull(origin: Vector3, user_mass: float, target: Node3D, strength: float, dir_sign: float,
		delta: float, reach: float, base_force := BASE_FORCE) -> Vector3:
	var to := center_of(target) - origin
	var dist := to.length()
	if dist < 0.25:
		return Vector3.ZERO
	var dir := to / dist * dir_sign  # dirección en la que se mueve el objetivo
	# La fuerza se mantiene entera en el primer tramo del alcance y recién después decae.
	var falloff := pow(clampf(1.0 - maxf(dist / reach - FALLOFF_PLATEAU, 0.0) / (1.0 - FALLOFF_PLATEAU), 0.0, 1.0), 1.5)
	var force := base_force * strength * falloff

	# Si el objetivo ya sale disparado libremente, deja de "apoyarse" en él.
	var share := 1.0
	var mass := movable_mass(target)
	if mass > 0.0:
		var rb := target as RigidBody3D
		var vel: Vector3 = rb.linear_velocity if rb else target.velocity
		share = clampf((MAX_TARGET_SPEED - vel.dot(dir)) / (MAX_TARGET_SPEED * 0.3), 0.0, 1.0)
		var dv := minf(force / mass * delta, MAX_DV_PER_STEP) * share
		if rb:
			rb.apply_central_impulse(dir * dv * mass)
		else:
			target.apply_allomantic_impulse(dir * dv)
	return -dir * force * share / user_mass


const ATIUM_COLOR := Color(0.92, 0.95, 1.0)


static func burns_atium(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var a: Allomancy = n.get(&"allomancy")
	return a != null and a.is_burning(&"atium")


## Atium: quien lo quema ve venir los golpes de quien no lo quema y los esquiva.
## Si los dos lo queman, se anulan: lo único que contrarresta el atium es el atium.
static func atium_edge(defender: Node, attacker: Node) -> bool:
	return burns_atium(defender) and not burns_atium(attacker)


## Probabilidad de crítico (daño x CRIT_MULT): con atium, contra quien no lo quema, ves el hueco
## exacto en la guardia. Sus golpes, además, no se pueden bloquear (ignoran armadura y peltre).
const CRIT_MULT := 2.0
static func crit_chance(attacker: Node, defender: Node) -> float:
	if not atium_edge(attacker, defender):
		return 0.05
	var a: Allomancy = attacker.get(&"allomancy")
	return 0.7 if a.is_flaring(&"atium") else 0.45


## Nubes de cobre activas: [centro, radio] de cada alomántico que quema cobre.
static func copper_clouds(tree: SceneTree) -> Array:
	var out := []
	for n in tree.get_nodes_in_group(&"allomancer_body"):
		var a: Allomancy = n.allomancy
		if a and a.is_burning(&"copper"):
			out.append([n.global_position + Vector3(0, 1.0, 0), COPPER_RADIUS * a.strength(&"copper")])
	return out


static func in_copper_cloud(tree: SceneTree, pos: Vector3) -> bool:
	for c in copper_clouds(tree):
		if pos.distance_to(c[0]) <= c[1]:
			return true
	return false


## Si un Buscador (bronce) puede sentir a este alomántico: quema algo que no sea cobre y no
## está dentro de una nube de cobre.
static func emits_pulses(body: Node3D) -> bool:
	var a: Allomancy = body.allomancy
	if a == null or in_copper_cloud(body.get_tree(), body.global_position + Vector3(0, 1.0, 0)):
		return false
	for m in a.burning_metals():
		if m != &"copper":
			return true
	return false
