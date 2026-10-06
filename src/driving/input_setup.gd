class_name InputSetup
extends RefCounted
## Registers the keyboard bindings used on desktop builds and in tests.

const BINDINGS := {
	"accelerate": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"steer_left": [KEY_A, KEY_LEFT],
	"steer_right": [KEY_D, KEY_RIGHT],
	"indicator_left": [KEY_Q],
	"indicator_right": [KEY_E],
	"camera_cycle": [KEY_C],
	"horn": [KEY_H],
	"pause": [KEY_ESCAPE],
}


static func ensure_actions() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var existing := InputMap.action_get_events(action)
		for keycode in BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			var already := existing.any(
				func(e: InputEvent) -> bool:
					return e is InputEventKey and e.physical_keycode == keycode
			)
			if not already:
				InputMap.action_add_event(action, event)
