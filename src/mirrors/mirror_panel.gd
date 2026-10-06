class_name MirrorPanel
extends Control
## The three mirror views laid out on screen for the driver's-seat camera:
## left mirror at the left edge, right mirror at the right edge, rear mirror
## top-centre.

var views := {}


func _init() -> void:
	name = "MirrorPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	views[MirrorRig.LEFT] = MirrorView.new(Vector2(180, 135))
	views[MirrorRig.RIGHT] = MirrorView.new(Vector2(180, 135))
	views[MirrorRig.REAR] = MirrorView.new(Vector2(320, 120))
	for view in views:
		views[view].name = view
		add_child(views[view])


func _ready() -> void:
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var left := views[MirrorRig.LEFT] as MirrorView
	var right := views[MirrorRig.RIGHT] as MirrorView
	var rear := views[MirrorRig.REAR] as MirrorView
	# Below the HUD text, above the indicator buttons / pedals.
	var y := size.y * 0.3
	left.position = Vector2(16, y)
	right.position = Vector2(size.x - right.size.x - 16, y)
	rear.position = Vector2((size.x - rear.size.x) / 2.0, 104)


func bind(rig: MirrorRig) -> void:
	for view in views:
		(views[view] as MirrorView).set_texture(rig.texture(view))
		(views[view] as MirrorView).set_broken(rig.broken[view])


func set_broken(view: String, is_broken: bool) -> void:
	(views[view] as MirrorView).set_broken(is_broken)
