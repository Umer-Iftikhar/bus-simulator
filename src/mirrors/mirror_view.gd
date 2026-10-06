class_name MirrorView
extends Control
## On-screen mirror: the mirror camera's image, flipped like a real mirror,
## framed, and covered with cracks (and darkened) once shattered.

const CRACK_COLOR := Color(0.9, 0.95, 1.0, 0.85)

var image := TextureRect.new()
var broken := false
var _cracks: Array[PackedVector2Array] = []


func _init(display_size := Vector2(192, 144)) -> void:
	custom_minimum_size = display_size
	size = display_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.flip_h = true
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)


func set_texture(texture: Texture2D) -> void:
	image.texture = texture


func set_broken(is_broken: bool) -> void:
	broken = is_broken
	image.modulate = Color(0.35, 0.35, 0.38) if broken else Color.WHITE
	_cracks.clear()
	if broken:
		_cracks = _make_cracks()
	queue_redraw()


func crack_count() -> int:
	return _cracks.size()


## A starburst of jagged cracks from an impact point (deterministic per name).
func _make_cracks() -> Array[PackedVector2Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var origin := size * Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7))
	var cracks: Array[PackedVector2Array] = []
	for i in 9:
		var angle := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		var line := PackedVector2Array([origin])
		var point := origin
		for segment in 4:
			angle += rng.randf_range(-0.4, 0.4)
			point += Vector2.from_angle(angle) * size.length() * rng.randf_range(0.08, 0.16)
			line.append(point)
		cracks.append(line)
	return cracks


func _draw() -> void:
	for line in _cracks:
		draw_polyline(line, CRACK_COLOR, 1.5, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05), false, 4.0)
