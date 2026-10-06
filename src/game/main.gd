extends Control
## Entry scene. Replaced by the full main menu as features land.


func _ready() -> void:
	var label := Label.new()
	label.text = "Bus Simulator"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(label)
