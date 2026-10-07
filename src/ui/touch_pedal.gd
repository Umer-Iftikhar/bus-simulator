class_name TouchPedal
extends TouchButton
## A held pedal. [member value] is 1.0 while a finger rests on it.

## Brake pedals are wide; accelerators are tall and narrow.
var wide := false

var value: float:
	get:
		return 1.0 if held else 0.0


func _init(text := "", min_size := Vector2(110, 170)) -> void:
	super(text, min_size)


func _draw() -> void:
	ControlArt.pedal(self, size, held, wide, label)
