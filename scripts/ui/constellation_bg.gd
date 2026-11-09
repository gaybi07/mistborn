class_name ConstellationBg
extends Control
## Fondo de "constelaciones" como el del árbol de habilidades (SkillTreeCanvas): puntos sueltos unidos con líneas muy
## tenues sobre el fondo oscuro. Llena su rectángulo; la cantidad de estrellas va con el área (misma densidad que el árbol).

const BG := Color(0.035, 0.04, 0.055)
const STAR := Color(0.6, 0.65, 0.8, 0.18)
const LINK := Color(0.5, 0.55, 0.7, 0.07)
const AREA_PER_STAR := 19000.0  # el árbol: 90 estrellas en 1900 x 900
const LINK_DIST := 150.0
const MAX_LINKS_PER_STAR := 1.6

var _stars := PackedVector2Array()
var _links: Array[Vector2i] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()


func _build() -> void:
	_stars.clear()
	_links.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(size.x * size.y / AREA_PER_STAR)
	for i in n:
		_stars.append(Vector2(rng.randf() * size.x, rng.randf() * size.y))
	for i in n:
		for j in range(i + 1, n):
			if _stars[i].distance_to(_stars[j]) < LINK_DIST and _links.size() < n * MAX_LINKS_PER_STAR:
				_links.append(Vector2i(i, j))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for l in _links:
		draw_line(_stars[l.x], _stars[l.y], LINK, 1.0, true)
	for p in _stars:
		draw_circle(p, 1.6, STAR)
