extends TestCase


func test_all_actions_registered_with_keys() -> void:
	InputSetup.ensure_actions()
	for action in InputSetup.BINDINGS:
		assert_true(InputMap.has_action(action), action)
		var keys := InputMap.action_get_events(action).map(
			func(e: InputEvent) -> int: return (e as InputEventKey).physical_keycode
		)
		for keycode in InputSetup.BINDINGS[action]:
			assert_has(keys, keycode, action)


func test_is_idempotent() -> void:
	InputSetup.ensure_actions()
	var before := InputMap.action_get_events("accelerate").size()
	InputSetup.ensure_actions()
	assert_eq(InputMap.action_get_events("accelerate").size(), before)
