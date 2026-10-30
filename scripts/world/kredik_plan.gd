class_name KredikPlan
## Planos de Kredik Shaw (ver docs/kredik_shaw.md): la misma planta sirve para el exterior
## (KredikCitadel) y para los mapas interiores de cada nivel (KredikLevel).
## Las medidas se copian de los planos de referencia en píxeles (imagen de 1408 × 768) y se pasan a
## metros con PX: x hacia el este, z hacia el sur (la Gran Entrada mira al sur, hacia la ciudad).
##
## Cada nivel es una lista de espacios que se pintan en orden sobre una cuadrícula de 1 m (los de
## después tapan a los de antes): [nombre, tipo, geometría, props, alto].
##   geometría: [x0, y0, x1, y1] (rectángulo) o [cx, cy, r] (círculo), en píxeles del plano.
##   tipo: court/terrace/garden (a cielo abierto), corridor, hall, throne, stair (escalera a otro
##   nivel), exit (salida a la ciudad), room, cells_x/cells_y (fila de celdas iguales), vault,
##   maze, pool, solid (muro macizo), rock (roca de los subniveles).
##   alto: 0 = el del tipo.

const PX := 0.15  ## metros por píxel del plano
const CENTER := Vector2(705, 388)  ## centro de la muralla exterior en el plano

## Mitad del rectángulo de la muralla exterior (m).
const HALF := Vector2(99.0, 47.6)

const LEVELS := ["sub3", "sub2", "sub1", "ground", "l2", "l3", "l4", "l5", "tower"]
const LEVEL_NAMES := {
	"sub3": "Subnivel 3 · Cimientos antiguos", "sub2": "Subnivel 2 · Archivos restringidos",
	"sub1": "Subnivel 1 · Arsenal y cuarteles", "ground": "Planta baja · Entrada imperial y Salón del Trono",
	"l2": "Nivel 2 · Administración imperial", "l3": "Nivel 3 · Ministerio de Acero",
	"l4": "Nivel 4 · Altos cargos del Ministerio", "l5": "Nivel 5 · Dominio del Lord Legislador",
	"tower": "Torre del Inquisidor",
}

## Alto por defecto de cada tipo (m).
const KIND_H := {"court": 0.0, "terrace": 0.0, "garden": 0.0, "corridor": 6.0, "hall": 11.0,
		"throne": 18.0, "stair": 9.0, "exit": 8.0, "room": 5.5, "cells_x": 4.5, "cells_y": 4.5,
		"vault": 5.0, "maze": 6.0, "pool": 7.0}
const OPEN_KINDS := ["court", "terrace", "garden"]
const CIRCULATION := ["court", "terrace", "garden", "corridor", "hall", "throne", "stair", "exit", "pool"]


## Píxel del plano -> metros (x, z) relativos al centro de la fortaleza.
static func m(px: Vector2) -> Vector2:
	return (px - CENTER) * PX


static func rect(r: Array) -> Rect2:
	var a := m(Vector2(r[0], r[1]))
	var b := m(Vector2(r[2], r[3]))
	return Rect2(a, b - a)


# ------------------------------------------------------------------ Piezas comunes

## Muralla exterior con torres cuadradas en las esquinas, muralla interior con sus cuatro torres
## redondas y huecos (puerta interior al sur, puente del trono al norte, pasos este y oeste), y las
## puertas oeste/este y la Gran Entrada. ward: el tipo del espacio entre murallas en este nivel.
static func _walls(ward: String, inner_ward: String) -> Array:
	var out := [
		["Muralla exterior", "solid", [45, 70, 1365, 705], "", 0],
		["Patio exterior", ward, [57, 82, 1353, 693], "", 0],
		["Muralla interior", "solid", [185, 175, 1215, 595], "", 0],
		["Patio interior de la muralla", inner_ward, [195, 185, 1205, 585], "", 0],
		["Paso oeste", ward, [180, 360, 200, 400], "", 0],
		["Paso este", ward, [1200, 360, 1220, 400], "", 0],
		["Paso norte", ward, [680, 170, 730, 190], "", 0],
	]
	for c in [[45, 70], [1325, 70], [45, 665], [1325, 665]]:
		out.append(["Torre de esquina", "solid", [c[0] - 6, c[1] - 6, c[0] + 46, c[1] + 46], "", 0])
	for c in [[205, 195], [1200, 195], [205, 575], [1200, 575]]:
		out.append(["Torre de la muralla interior", "solid", [c[0], c[1], 26], "", 0])
	out.append(["Puerta oeste", "solid", [28, 355, 62, 405], "", 0])
	out.append(["Puerta este", "solid", [1348, 355, 1382, 405], "", 0])
	return out


## Franja norte (complejo del trono y alas de servicio) con los nombres de cada nivel.
static func _north(names: Array, kinds: Array, props: Array) -> Array:
	var geo := [[160, 88, 365, 152], [370, 88, 500, 152], [500, 45, 612, 160], [612, 28, 798, 160],
			[798, 45, 915, 160], [915, 88, 1045, 152], [1045, 88, 1175, 152], [1175, 88, 1255, 152]]
	var out := [["Complejo del trono", "solid", [500, 28, 915, 160], "", 0]]
	for i in geo.size():
		if names[i] != "":
			out.append([names[i], kinds[i], geo[i], props[i], 0])
	return out


## El torreón: cuerpo con cuatro bastiones redondos, patio central y las dos grandes escaleras.
static func _keep(top: String, court: String, court_kind: String, court_props: String, top_props: String) -> Array:
	return [
		["Pasillos del torreón", "corridor", [565, 245, 870, 480], "", 0],
		["Bastión", "solid", [585, 265, 26], "", 0],
		["Bastión", "solid", [850, 265, 26], "", 0],
		["Bastión", "solid", [585, 460, 26], "", 0],
		["Bastión", "solid", [850, 460, 26], "", 0],
		[top, "hall", [598, 255, 842, 335], top_props, 13.0],
		["Gran Escalera oeste", "stair", [580, 342, 636, 432], "", 0],
		["Gran Escalera este", "stair", [774, 342, 830, 432], "", 0],
		[court, court_kind, [642, 345, 768, 440], court_props, 0],
		["Galería del trono", "hall", [685, 160, 725, 255], "banners", 10.0],
		["Vía Procesional", "hall", [688, 480, 722, 548], "banners", 9.0],
		["Puerta interior", "hall", [680, 545, 730, 602], "", 10.0],
		["Torre de la puerta interior", "solid", [656, 572, 15], "", 0],
		["Torre de la puerta interior", "solid", [754, 572, 15], "", 0],
	]


## Gran Entrada: el portón entre dos torres redondas que sobresale al sur.
static func _gate(name: String, kind: String) -> Array:
	return [
		[name, kind, [680, 688, 730, 742], "banners", 12.0],
		["Torre de la Gran Entrada", "solid", [664, 716, 17], "", 0],
		["Torre de la Gran Entrada", "solid", [746, 716, 17], "", 0],
	]


# ------------------------------------------------------------------ Niveles

static func spaces(level: String) -> Array:
	match level:
		"ground":
			return _ground()
		"l2":
			return _l2()
		"l3":
			return _l3()
		"l4":
			return _l4()
		"l5":
			return _l5()
		"sub1":
			return _sub1()
		"sub2":
			return _sub2()
		"sub3":
			return _sub3()
	return []


## Escaleras y salidas: nombre del espacio -> [nivel destino, espacio destino, rótulo, sentido].
## sentido: "up" (sube: escalera y puerta arriba), "down" (baja), "out" (sale a la ciudad).
static func links(level: String) -> Dictionary:
	match level:
		"ground":
			return {
				"Gran Escalera oeste": ["l2", "Gran Escalera oeste", "Subir al Nivel 2", "up"],
				"Gran Escalera este": ["l2", "Gran Escalera este", "Subir al Nivel 2", "up"],
				"Puertas del subnivel": ["sub1", "Acceso imperial", "Bajar al Subnivel 1", "down"],
				"Entrada Imperial": ["city", "", "Salir a Luthadel", "out"],
			}
		"l2", "l3", "l4":
			var below: String = {"l2": "ground", "l3": "l2", "l4": "l3"}[level]
			var above: String = {"l2": "l3", "l3": "l4", "l4": "l5"}[level]
			var n_above: String = {"l2": "3", "l3": "4", "l4": "5"}[level]
			var n_below: String = {"l2": "la planta baja", "l3": "el Nivel 2", "l4": "el Nivel 3"}[level]
			var out := {
				"Gran Escalera oeste": [above, "Gran Escalera oeste", "Subir al Nivel " + n_above, "up", below, "Bajar a " + n_below],
				"Gran Escalera este": [above, "Gran Escalera este", "Subir al Nivel " + n_above, "up", below, "Bajar a " + n_below],
			}
			if level == "l3":
				out["Acceso a la Torre del Inquisidor"] = ["tower", "Base de la torre", "Torre del Inquisidor", "up"]
			return out
		"l5":
			return {
				"Gran Escalera oeste": ["l4", "Gran Escalera oeste", "Bajar al Nivel 4", "down"],
				"Gran Escalera este": ["l4", "Gran Escalera este", "Bajar al Nivel 4", "down"],
			}
		"sub1":
			return {
				"Acceso imperial": ["ground", "Puertas del subnivel", "Subir a la planta baja", "up"],
				"Pozo vertical": ["sub2", "Pozo vertical", "Bajar al Subnivel 2", "down"],
				"Salida de emergencia": ["city", "", "Salir a Luthadel", "out"],
			}
		"sub2":
			return {
				"Pozo vertical": ["sub1", "Pozo vertical", "Subir al Subnivel 1", "up", "sub3", "Bajar al Subnivel 3"],
			}
		"sub3":
			return {
				"Pozo vertical": ["sub2", "Pozo vertical", "Subir al Subnivel 2", "up"],
				"Salida de la cueva": ["city", "", "Salir a Luthadel", "out"],
			}
	return {}


static func _ground() -> Array:
	var s := _walls("court", "court")
	s += _north(["Ala de servicio", "Alas de servicio", "Escalera de servicio", "Salón del Trono", "Cámaras del trono",
			"Ala de servicio este", "Estudios privados", "Estudio de Adan"],
			["room", "room", "room", "throne", "cells_x", "room", "cells_x", "room"],
			["crates", "crates", "crates", "throne", "shelves", "crates", "desks", "library"])
	s += [
		["Cuartos de guardia", "cells_y", [70, 160, 160, 330], "bunks", 0],
		["Almacén oeste", "room", [70, 450, 235, 693], "crates", 7.0],
		["Oficinas administrativas", "cells_y", [1255, 200, 1340, 330], "desks", 0],
		# Ministerio (oeste)
		["Pasillos del Ministerio", "corridor", [230, 220, 552, 545], "", 0],
		["Cámara de audiencias públicas", "hall", [240, 228, 316, 330], "benches", 9.0],
		["Sala de espera", "room", [320, 228, 360, 312], "benches", 0],
		["Sala de espera norte", "room", [362, 228, 530, 258], "benches", 0],
		["Patio del Ministerio norte", "court", [362, 262, 530, 300], "statue", 0],
		["Control de guardia", "room", [236, 340, 300, 398], "table", 0],
		["Sala de espera central", "room", [350, 320, 468, 356], "benches", 0],
		["Control de guardia este", "room", [472, 330, 530, 376], "table", 0],
		["Control de guardia sur", "room", [250, 400, 340, 432], "table", 0],
		["Patio del Ministerio", "court", [362, 370, 466, 456], "fountain", 0],
		["Alas de servicio del Ministerio", "room", [362, 462, 452, 492], "crates", 0],
		["Puesto de guardia", "room", [258, 516, 24], "table", 0],
		["Despachos del Ministerio", "cells_y", [472, 384, 546, 540], "desks", 0],
	]
	s += _keep("Gran Salón", "Patio interior", "court", "fountain", "columns banners")
	s += [
		# Cuarteles y Patio de Armas (noreste)
		["Cuarteles de la Guardia", "cells_x", [895, 220, 1180, 252], "bunks", 0],
		["Celdas de la Guardia", "cells_y", [895, 256, 940, 360], "bunks", 0],
		["Patio de Armas", "court", [944, 256, 1180, 360], "weapons", 0],
		# Complejo inquisitorial (este)
		["Complejo inquisitorial", "corridor", [960, 395, 1195, 545], "", 0],
		["Celdas inquisitoriales norte", "cells_x", [1000, 400, 1190, 434], "cell", 0],
		["Celdas inquisitoriales sur", "cells_x", [1000, 510, 1190, 545], "cell", 0],
		["Celdas inquisitoriales este", "cells_y", [1150, 438, 1190, 506], "cell", 0],
		["Patio Inquisitorial", "court", [1030, 440, 1106, 506], "statue", 0],
		["Sala segura", "vault", [966, 494, 1000, 540], "chests", 0],
		# Franja sur
		["Sala de espera sur", "hall", [415, 602, 602, 690], "benches", 9.0],
		["Salón Procesional", "hall", [610, 602, 800, 688], "columns banners", 14.0],
		["Puertas del subnivel", "stair", [612, 604, 668, 686], "", 7.0],
		["Recepción administrativa", "hall", [808, 602, 992, 690], "desks", 9.0],
		["Alas de servicio sur", "room", [1000, 625, 1100, 690], "crates", 0],
		["Puesto de guardia privado", "room", [1105, 635, 1225, 690], "table", 0],
		["Almacenes este", "room", [1250, 430, 1340, 690], "crates", 7.0],
	]
	s += _gate("Entrada Imperial", "exit")
	return s


static func _l2() -> Array:
	var s := _walls("corridor", "corridor")
	s += _north(["Almacén seguro", "Alas de servicio", "Escalera de servicio", "Complejo del trono (acceso inferior)",
			"Cámaras del trono", "Suites de la administración", "Acceso a los Grandes Archivos", "Accesos al archivo superior"],
			["vault", "room", "room", "hall", "cells_x", "cells_x", "room", "room"],
			["chests", "crates", "crates", "columns", "shelves", "desks", "shelves", "shelves"])
	s += [
		["Centro de registros regionales (oeste)", "room", [70, 90, 160, 330], "shelves", 0],
		["Almacén seguro (oeste)", "vault", [70, 450, 235, 693], "chests", 0],
		["Centro de registros regionales (noreste)", "room", [1255, 150, 1340, 330], "shelves", 0],
		["Centro de registros regionales (sureste)", "room", [1250, 430, 1340, 690], "shelves", 0],
		["Pasillos del Ministerio", "corridor", [230, 220, 552, 545], "", 0],
		["Archivo regional A", "room", [240, 228, 316, 330], "shelves", 0],
		["Sala de espera", "room", [320, 228, 360, 312], "benches", 0],
		["Sala de espera norte", "room", [362, 228, 530, 258], "benches", 0],
		["Patio", "court", [362, 262, 530, 300], "", 0],
		["Archivo regional de Aredel", "room", [236, 340, 300, 398], "shelves", 0],
		["Archivo regional", "room", [350, 320, 468, 356], "shelves", 0],
		["Oficinas del censo (norte)", "room", [472, 330, 530, 376], "desks", 0],
		["Oficinas del censo (B)", "room", [250, 400, 340, 432], "desks", 0],
		["Sucursal del censo de Luthadel", "hall", [362, 370, 466, 456], "desks", 7.0],
		["Oficinas del censo", "room", [362, 462, 452, 492], "desks", 0],
		["Puesto de guardia", "room", [258, 516, 24], "table", 0],
		["Despachos del censo", "cells_y", [472, 384, 546, 540], "desks", 0],
	]
	s += _keep("Complejo de escribientes", "Taller central de escribientes", "hall", "desks", "desks")
	s += [
		["Puntos de recaudación", "room", [610, 490, 684, 545], "desks", 0],
		["Puestos de admisión", "room", [726, 490, 800, 545], "desks", 0],
		["Pasillos de la Oficina de Impuestos", "corridor", [895, 220, 1180, 360], "", 0],
		["Oficinas de impuestos norte", "cells_x", [900, 222, 1178, 250], "desks", 0],
		["Oficinas de impuestos sur", "cells_x", [900, 330, 1178, 358], "desks", 0],
		["Sala central de escribientes", "hall", [950, 262, 1130, 322], "desks", 7.0],
		["Complejo inquisitorial", "corridor", [960, 395, 1195, 545], "", 0],
		["Oficinas del censo (este) norte", "cells_x", [1000, 400, 1190, 434], "desks", 0],
		["Oficinas del censo (este) sur", "cells_x", [1000, 510, 1190, 545], "desks", 0],
		["Sucursal de la Oficina del Censo", "hall", [1030, 440, 1146, 506], "desks", 7.0],
		["Sala segura", "vault", [966, 494, 1000, 540], "chests", 0],
		["Cuarteles de la Guardia oeste", "cells_x", [415, 602, 602, 690], "bunks", 0],
		["Ruta Procesional", "hall", [610, 602, 800, 688], "columns banners", 9.0],
		["Cuarteles de la Guardia este", "cells_x", [808, 602, 992, 690], "bunks", 0],
		["Mensajería y admisión", "room", [1000, 625, 1100, 690], "table", 0],
		["Clasificación de documentos", "room", [1105, 635, 1225, 690], "desks", 0],
	]
	return s


static func _l3() -> Array:
	var s := _walls("corridor", "corridor")
	s += _north(["Almacén seguro", "Alas de servicio", "Escalera de servicio", "Control de la Guardia Real y de los obligadores",
			"Cámaras del trono", "Suites de la administración", "Acceso a los Grandes Archivos", "Accesos al archivo superior"],
			["vault", "room", "room", "hall", "cells_x", "cells_x", "room", "room"],
			["chests", "crates", "crates", "table", "shelves", "desks", "shelves", "shelves"])
	s += [
		["Centro de registros regionales (oeste)", "room", [70, 90, 160, 330], "shelves", 0],
		["Almacén seguro (oeste)", "vault", [70, 450, 235, 693], "chests", 0],
		["Centro de registros regionales (noreste)", "room", [1255, 150, 1340, 330], "shelves", 0],
		["Centro de registros regionales (sureste)", "room", [1250, 430, 1340, 690], "shelves", 0],
		["Pasillos del Ministerio", "corridor", [230, 220, 552, 545], "", 0],
		["Cámaras de reunión nobles", "room", [236, 228, 330, 330], "round_table", 0],
		["Tribunal de cumplimiento burocrático", "hall", [362, 228, 530, 300], "benches", 8.0],
		["Oficinas del censo (norte)", "room", [472, 304, 530, 346], "desks", 0],
		["Cámaras de recepción nobles", "room", [236, 336, 330, 420], "round_table", 0],
		["Cámaras de recepción nobles (patio)", "hall", [362, 346, 466, 460], "round_table", 7.0],
		["Cámara de reunión noble oeste", "room", [342, 464, 410, 512], "round_table", 0],
		["Cámara de reunión noble este", "room", [414, 464, 466, 512], "round_table", 0],
		["Oficinas de la guardia", "room", [282, 474, 30], "table", 0],
		["Despachos de los obligadores", "cells_y", [472, 384, 546, 540], "desks", 0],
	]
	s += _keep("Complejo del Archivo de los obligadores", "Sala de trabajo del prefecto", "hall", "desks", "shelves")
	s += [
		["Control de los obligadores", "room", [610, 490, 684, 545], "table", 0],
		["Puestos de admisión", "room", [726, 490, 800, 545], "desks", 0],
		["Pasillos restringidos de acero", "corridor", [895, 220, 1190, 545], "", 0],
		["Celdas del Ministerio norte", "cells_x", [900, 222, 1186, 252], "desks", 0],
		["Celdas del Ministerio oeste", "cells_y", [900, 256, 940, 540], "desks", 0],
		["Celdas del Ministerio este", "cells_y", [1150, 256, 1188, 540], "desks", 0],
		["Tribunal de los Inquisidores de Acero", "hall", [966, 282, 1146, 330], "altar", 8.0],
		["Despacho del Alto Prefecto", "hall", [966, 336, 1146, 448], "table", 8.0],
		["Oficinas de los Inquisidores de Acero", "cells_x", [966, 452, 1146, 510], "desks", 0],
		["Acceso a la Torre del Inquisidor", "stair", [1110, 512, 1146, 545], "", 6.0],
		["Cuarteles de la Guardia oeste", "cells_x", [415, 602, 602, 690], "bunks", 0],
		["Ruta Procesional (control de obligadores)", "hall", [610, 602, 800, 688], "columns banners", 9.0],
		["Cuarteles de la Guardia este", "cells_x", [808, 602, 992, 690], "bunks", 0],
		["Mensajería y admisión", "room", [1000, 625, 1100, 690], "table", 0],
		["Clasificación de documentos", "room", [1105, 635, 1225, 690], "desks", 0],
	]
	return s


static func _l4() -> Array:
	var s := _walls("corridor", "corridor")
	s += _north(["Almacén seguro", "Alas de servicio", "Escalera de servicio", "",
			"Centro de mando fortificado", "Mando de seguridad de los Cantones", "Acceso a los Grandes Archivos", "Registros ministeriales"],
			["vault", "room", "room", "", "room", "room", "room", "room"],
			["chests", "crates", "crates", "", "map_table", "desks", "shelves", "shelves"])
	s += [
		["Cámaras del Consejo de los Seis", "hall", [705, 92, 78], "council", 14.0],
		["Control de la Llave Maestra", "vault", [800, 112, 912, 158], "chests", 0],
		["Complejo de Relaciones Diplomáticas", "room", [70, 90, 160, 330], "round_table", 0],
		["Suite del Alto Obligador Lord A", "room", [70, 455, 160, 540], "bed", 0],
		["Sala de espera", "room", [70, 545, 160, 595], "benches", 0],
		["Suite del Alto Obligador A", "room", [70, 600, 235, 693], "bed", 0],
		["Suites administrativas ministeriales", "room", [1255, 150, 1340, 330], "desks", 0],
		["Suite del Alto Obligador B", "room", [1255, 430, 1340, 520], "bed", 0],
		["Suite del Alto Obligador C", "room", [1255, 524, 1340, 610], "bed", 0],
		["Suite del Alto Obligador D", "room", [1255, 614, 1340, 690], "bed", 0],
		["Pasillos del Ministerio", "corridor", [230, 220, 552, 545], "", 0],
		["Complejo de Relaciones Diplomáticas (interior)", "room", [236, 228, 330, 330], "round_table", 0],
		["Tribunal de cumplimiento burocrático", "hall", [362, 228, 530, 300], "benches", 8.0],
		["Oficinas del censo (norte)", "room", [472, 304, 530, 346], "desks", 0],
		["Cámaras de recepción nobles", "room", [236, 336, 330, 420], "round_table", 0],
		["Cámaras de recepción nobles (patio)", "hall", [362, 346, 466, 460], "round_table", 7.0],
		["Cámara de reunión noble oeste", "room", [342, 464, 410, 512], "round_table", 0],
		["Cámara de reunión noble este", "room", [414, 464, 466, 512], "round_table", 0],
		["Cámara de espera", "room", [472, 462, 546, 522], "benches", 0],
		["Oficinas de la guardia", "room", [282, 474, 30], "table", 0],
	]
	s += _keep("Cuartel general de los Cantones y centro de operaciones", "Mesa de los mapas", "hall", "map_table", "map_table")
	s += [
		["Puertas de alto nivel", "room", [610, 490, 684, 545], "table", 0],
		["Puertas de alto nivel (este)", "room", [726, 490, 800, 545], "table", 0],
		["Complejo de Inteligencia", "corridor", [895, 220, 1190, 545], "", 0],
		["Celdas de Inteligencia norte", "cells_x", [900, 222, 1186, 252], "desks", 0],
		["Celdas de Inteligencia oeste", "cells_y", [900, 256, 940, 540], "desks", 0],
		["Archivo de Inteligencia", "room", [966, 282, 1060, 346], "shelves", 0],
		["Sala secreta", "vault", [1064, 282, 1146, 346], "chests", 0],
		["Altas Salas", "hall", [966, 350, 1146, 380], "banners", 7.0],
		["Entrada privada de observación", "room", [966, 384, 1146, 420], "benches", 0],
		["Despachos de los Altos Obligadores", "cells_x", [966, 424, 1146, 470], "desks", 0],
		["Cuarteles de la Guardia oeste", "cells_x", [415, 602, 602, 690], "bunks", 0],
		["Acceso procesional de alto nivel (control)", "hall", [610, 602, 800, 688], "columns banners", 9.0],
		["Cuarteles de la Guardia este", "cells_x", [808, 602, 992, 690], "bunks", 0],
		["Suite del Alto Obligador E", "room", [1000, 610, 1110, 690], "bed", 0],
		["Suite del Alto Obligador F", "room", [1115, 610, 1225, 690], "bed", 0],
	]
	return s


static func _l5() -> Array:
	var s := _walls("terrace", "terrace")
	s += [
		["Complejo del trono", "solid", [500, 28, 915, 160], "", 0],
		["Escalera privada", "room", [500, 45, 612, 160], "", 0],
		["Alcoba del Lord Legislador", "hall", [705, 100, 84], "bed", 9.0],
		["Cámara de baño", "room", [798, 45, 915, 86], "bath", 0],
		["Vestidor", "room", [798, 90, 915, 132], "shelves", 0],
		["Pasaje fuertemente custodiado", "corridor", [798, 136, 915, 160], "banners", 0],
		["Biblioteca Imperial", "room", [915, 88, 1045, 152], "library", 0],
		["Estudio sagrado", "room", [1045, 88, 1175, 152], "altar", 0],
		["Cámara de baño este", "room", [1175, 88, 1255, 152], "bath", 0],
		# Terrazas ajardinadas (oeste)
		["Terrazas ajardinadas", "garden", [222, 222, 552, 548], "garden", 0],
		["Jardín noroeste", "garden", [290, 290, 60], "garden", 0],
		["Jardín suroeste", "garden", [290, 480, 60], "garden", 0],
		["Gran jardín", "garden", [400, 385, 72], "fountain", 0],
		["Acceso privado a la terraza", "terrace", [130, 360, 222, 420], "", 0],
		# Salón de recepción
		["Salón de recepción", "hall", [552, 222, 830, 548], "columns", 12.0],
		["Comedor privado", "room", [612, 345, 798, 402], "table", 6.0],
		["Gran Escalera oeste", "stair", [560, 455, 610, 545], "", 0],
		["Gran Escalera este", "stair", [776, 455, 826, 545], "", 0],
		["Salas de meditación norte", "room", [832, 225, 892, 290], "altar", 0],
		["Salas de meditación", "room", [832, 352, 892, 392], "altar", 0],
		["Sala de audiencias restringida", "room", [835, 396, 945, 455], "throne", 0],
		["Sala de audiencias restringida sur", "room", [835, 460, 945, 545], "benches", 0],
		# Cámaras sagradas (este)
		["Cámaras sagradas", "corridor", [896, 222, 1190, 548], "", 0],
		["Celdas sagradas norte", "cells_x", [950, 225, 1186, 260], "altar", 0],
		["Celdas sagradas sur", "cells_x", [950, 512, 1186, 546], "altar", 0],
		["Cámara de los Ancestros", "hall", [966, 282, 1146, 470], "statues", 10.0],
		["Santuario interior", "room", [1010, 340, 1100, 420], "altar", 7.0],
		# Sur
		["Acceso imperial", "hall", [615, 548, 800, 600], "banners", 8.0],
		["Cuarteles de la Guardia oeste", "cells_x", [415, 602, 602, 690], "bunks", 0],
		["Acceso imperial (puertas de personal)", "hall", [610, 602, 800, 688], "banners", 9.0],
		["Cuarteles de la Guardia este", "cells_x", [808, 602, 992, 690], "bunks", 0],
	]
	return s


## Los subniveles: un bloque macizo excavado en la roca bajo el torreón.
static func _sub_base() -> Array:
	return [
		["Roca", "rock", [0, 0, 1408, 768], "", 0],
		["Rotonda", "hall", [710, 96, 80], "vault_dome", 8.0],
		["Escalera de servicio", "room", [500, 45, 612, 160], "crates", 0],
		["Cámara norte", "room", [798, 45, 915, 160], "crates", 0],
		["Altas Salas", "corridor", [330, 556, 620, 590], "", 0],
		["Pasillos restringidos de acero", "corridor", [800, 556, 1060, 590], "", 0],
	]


## El pozo que une los tres subniveles (va al final: tapa a los pasillos).
const SHAFT := ["Pozo vertical", "stair", [1150, 228, 1190, 288], "", 9.0]


static func _sub1() -> Array:
	var s := _sub_base()
	s += [
		["Almacenes de víveres", "room", [205, 225, 552, 548], "crates", 0],
		["Cámaras frías", "hall", [398, 386, 76], "crates", 7.0],
		["Salón de recepción (cuarteles)", "hall", [552, 222, 830, 548], "bunks", 7.0],
		["Salas de meditación", "room", [832, 225, 892, 290], "altar", 0],
		["Salas de meditación sur", "room", [832, 352, 892, 392], "altar", 0],
		["Zona de descanso de la guardia", "room", [850, 398, 940, 460], "table", 0],
		["Almacén de equipo táctico", "room", [850, 464, 940, 545], "weapons", 0],
		["Almacén de equipo táctico (este)", "room", [896, 222, 1146, 280], "weapons", 0],
		["Cuarteles", "hall", [966, 282, 1146, 470], "bunks", 6.0],
		["Pasillo este", "corridor", [1146, 222, 1192, 548], "", 0],
		["Pasillo sur", "corridor", [896, 470, 1146, 548], "", 0],
		["Armerías", "room", [410, 592, 602, 690], "weapons", 0],
		["Centro militar de logística", "hall", [610, 592, 800, 690], "crates", 7.0],
		["Acceso imperial", "stair", [615, 548, 800, 592], "", 6.0],
		["Almacenes de suministros", "room", [808, 592, 992, 690], "crates", 0],
		["Salida de emergencia", "exit", [130, 370, 205, 420], "", 5.0],
		SHAFT,
	]
	return s


static func _sub2() -> Array:
	var s := _sub_base()
	s += [
		["Archivos centrales restringidos", "room", [205, 225, 552, 548], "shelves", 0],
		["Registros seguros", "hall", [398, 386, 76], "shelves", 7.0],
		["Archivos centrales", "hall", [552, 222, 830, 548], "", 7.0],
		["Bóveda restringida 1", "vault", [615, 280, 700, 360], "chests", 0],
		["Bóveda restringida 2", "vault", [720, 280, 805, 360], "chests", 0],
		["Bóveda restringida 3", "vault", [615, 400, 700, 480], "chests", 0],
		["Bóveda restringida 4", "vault", [720, 400, 805, 480], "chests", 0],
		["Depósito de registros secretos", "room", [832, 225, 900, 360], "shelves", 0],
		["Objetos confiscados (no metálicos)", "room", [832, 365, 950, 420], "crates", 0],
		["Objetos confiscados (no metálicos) sur", "room", [832, 424, 950, 545], "crates", 0],
		["Inspección interna y seguridad", "corridor", [896, 222, 1192, 280], "", 0],
		["Archivos laberínticos", "maze", [966, 282, 1146, 470], "shelves", 0],
		["Pasillo este", "corridor", [1146, 280, 1192, 548], "", 0],
		["Pasillo sur", "corridor", [950, 470, 1146, 548], "", 0],
		["Bóveda de artefactos confiscados", "vault", [410, 592, 602, 690], "chests", 0],
		["Acceso de personal mínimo", "hall", [610, 592, 800, 690], "", 6.0],
		["Almacén de material restringido", "vault", [808, 592, 992, 690], "chests", 0],
		["Puertas del subnivel", "corridor", [615, 548, 800, 592], "", 0],
		SHAFT,
	]
	return s


static func _sub3() -> Array:
	var s := _sub_base()
	s += [
		["Cripta olvidada", "room", [205, 225, 380, 384], "statues", 0],
		["Santuario de los dioses antiguos", "room", [205, 388, 380, 548], "altar", 0],
		["Cimientos antiguos", "hall", [384, 225, 552, 548], "", 7.0],
		["Núcleo de la cisterna", "pool", [398, 386, 70], "", 9.0],
		["Cisterna", "pool", [520, 335, 580, 410], "", 0],
		["Estudio de artefactos olvidados", "hall", [552, 222, 830, 548], "shelves", 7.0],
		["Cripta de registros podridos", "room", [615, 280, 700, 360], "shelves", 0],
		["Archivos olvidados", "room", [720, 280, 805, 360], "shelves", 0],
		["Cámara olvidada", "room", [615, 400, 700, 480], "statues", 0],
		["Cámara olvidada este", "room", [720, 400, 805, 480], "chests", 0],
		["Bóveda del tesoro oculta", "maze", [832, 225, 962, 362], "chests", 0],
		["Cámara ritual restringida", "room", [832, 366, 962, 450], "altar", 0],
		["Cámara ritual restringida sur", "room", [832, 454, 962, 545], "altar", 0],
		["Laberinto", "maze", [966, 282, 1146, 470], "", 0],
		["Pasillo este", "corridor", [1146, 222, 1192, 548], "", 0],
		["Pasillo norte", "corridor", [966, 222, 1146, 280], "", 0],
		["Pasillo sur", "corridor", [966, 470, 1146, 548], "", 0],
		["Almacén de material confiscado", "vault", [1000, 150, 1100, 222], "chests", 0],
		["Catacumbas antiguas", "room", [410, 592, 602, 690], "statues", 0],
		["Acceso de personal mínimo", "hall", [610, 592, 800, 690], "", 6.0],
		["Depósito de secretos sin cartografiar", "room", [808, 592, 992, 690], "crates", 0],
		["Pozo de acceso inferior", "room", [612, 548, 650, 590], "shaft", 0],
		["Puertas del subnivel", "corridor", [654, 548, 800, 592], "", 0],
		["Cueva", "corridor", [100, 330, 205, 450], "", 0],
		["Salida de la cueva", "exit", [60, 360, 110, 420], "", 5.0],
		SHAFT,
	]
	return s


# ------------------------------------------------------------------ Exterior

## Volúmenes del exterior que no son murallas ni torres: [px, alto de cornisa, tejado, ventanas].
## tejado: "gable" (a dos aguas, cumbrera en el lado largo), "flat" (azotea con almenas).
const MASSES := [
	# Ministerio (oeste): bloques de alturas distintas alrededor de sus patios.
	[[230, 220, 552, 262], 24.0, "gable", true],
	[[230, 262, 360, 545], 26.0, "gable", true],
	[[466, 300, 552, 545], 22.0, "gable", true],
	[[360, 300, 466, 370], 20.0, "gable", true],
	[[360, 456, 466, 545], 20.0, "gable", true],
	# Cuarteles y celdas (noreste)
	[[895, 220, 1182, 254], 15.0, "gable", true],
	[[895, 254, 942, 362], 15.0, "gable", true],
	# Complejo inquisitorial (este): un anillo alrededor de su patio.
	[[960, 395, 1196, 438], 24.0, "flat", true],
	[[960, 506, 1196, 546], 24.0, "flat", true],
	[[960, 438, 1030, 506], 24.0, "flat", true],
	[[1106, 438, 1196, 506], 24.0, "flat", true],
	# Franja sur: cuarteles y salones a los lados del Salón Procesional.
	[[415, 600, 604, 692], 14.0, "gable", true],
	[[806, 600, 994, 692], 14.0, "gable", true],
	[[608, 600, 802, 690], 20.0, "gable", true],
	[[1000, 622, 1226, 692], 12.0, "gable", true],
	# Almacenes y alas entre murallas.
	[[70, 450, 236, 694], 11.0, "gable", false],
	[[1248, 430, 1342, 694], 11.0, "gable", false],
	[[70, 88, 162, 332], 16.0, "gable", true],
	[[1253, 150, 1342, 332], 16.0, "gable", true],
	[[160, 86, 500, 154], 16.0, "gable", true],
	[[915, 86, 1257, 154], 16.0, "gable", true],
	# Complejo del trono (alas a los lados de la nave).
	[[500, 40, 612, 162], 30.0, "flat", true],
	[[798, 40, 915, 162], 30.0, "flat", true],
]
