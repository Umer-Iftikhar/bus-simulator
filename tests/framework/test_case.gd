class_name TestCase
extends RefCounted
## Base class for every test file.
##
## The runner instantiates each `test_*.gd` file, then calls every method whose
## name starts with `test_`. Test methods may be coroutines (use `await`).
## Nodes added through [method add_child_autofree] are freed after each test.

const SIGNAL_ARG_SLOTS := 6

var _tree: SceneTree
var _failures: PackedStringArray = []
var _assert_count := 0
var _autofree: Array[Object] = []
var _signal_log := {}


## Hook: runs once before the first test in the file.
func before_all() -> void:
	pass


## Hook: runs once after the last test in the file.
func after_all() -> void:
	pass


## Hook: runs before every test.
func before_each() -> void:
	pass


## Hook: runs after every test (before autofree cleanup).
func after_each() -> void:
	pass


func get_tree() -> SceneTree:
	return _tree


# ---------------------------------------------------------------------------
# Lifecycle helpers
# ---------------------------------------------------------------------------


## Adds [param node] under the scene root; it is freed after the current test.
func add_child_autofree(node: Node) -> Node:
	_tree.root.add_child(node)
	_autofree.append(node)
	return node


## Registers [param obj] to be freed after the current test.
func autofree(obj: Object) -> Object:
	_autofree.append(obj)
	return obj


func wait_physics_frames(count: int) -> void:
	for i in count:
		await _tree.physics_frame


func wait_process_frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


## Waits the number of physics ticks equivalent to [param seconds] of game time.
func wait_seconds(seconds: float) -> void:
	var ticks := ceili(seconds * Engine.physics_ticks_per_second)
	await wait_physics_frames(ticks)


## Steps physics until [param predicate] returns true or [param max_seconds] passes.
## Returns true when the predicate was satisfied.
func wait_until(predicate: Callable, max_seconds: float) -> bool:
	var ticks := ceili(max_seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		if predicate.call():
			return true
		await _tree.physics_frame
	return predicate.call()


## Frees everything registered for autofree. Called by the runner.
func _cleanup() -> void:
	for obj in _autofree:
		if is_instance_valid(obj):
			if obj is Node:
				var node := obj as Node
				if node.is_inside_tree():
					node.get_parent().remove_child(node)
				node.free()
			elif not (obj is RefCounted):
				obj.free()
	_autofree.clear()
	_signal_log.clear()


# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------


func fail(message: String) -> void:
	_assert_count += 1
	_record_failure(message)


func pass_test() -> void:
	_assert_count += 1


func assert_true(value: bool, message := "") -> void:
	_check(value, "expected true but was false", message)


func assert_false(value: bool, message := "") -> void:
	_check(not value, "expected false but was true", message)


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	var ok := _values_equal(actual, expected)
	_check(ok, "expected [%s] but got [%s]" % [str(expected), str(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message := "") -> void:
	var ok := not _values_equal(actual, unexpected)
	_check(ok, "expected value different from [%s]" % str(unexpected), message)


func assert_almost_eq(actual: float, expected: float, tolerance: float, message := "") -> void:
	var ok := absf(actual - expected) <= tolerance
	var detail := "expected %s ± %s but got %s" % [expected, tolerance, actual]
	_check(ok, detail, message)


func assert_vec3_almost_eq(
	actual: Vector3, expected: Vector3, tolerance: float, message := ""
) -> void:
	var ok := actual.distance_to(expected) <= tolerance
	_check(ok, "expected %s ± %s but got %s" % [expected, tolerance, actual], message)


func assert_gt(actual: Variant, bound: Variant, message := "") -> void:
	_check(actual > bound, "expected %s > %s" % [str(actual), str(bound)], message)


func assert_ge(actual: Variant, bound: Variant, message := "") -> void:
	_check(actual >= bound, "expected %s >= %s" % [str(actual), str(bound)], message)


func assert_lt(actual: Variant, bound: Variant, message := "") -> void:
	_check(actual < bound, "expected %s < %s" % [str(actual), str(bound)], message)


func assert_le(actual: Variant, bound: Variant, message := "") -> void:
	_check(actual <= bound, "expected %s <= %s" % [str(actual), str(bound)], message)


func assert_between(actual: Variant, low: Variant, high: Variant, message := "") -> void:
	var ok: bool = actual >= low and actual <= high
	_check(ok, "expected %s within [%s, %s]" % [str(actual), str(low), str(high)], message)


func assert_null(value: Variant, message := "") -> void:
	_check(value == null, "expected null but got [%s]" % str(value), message)


func assert_not_null(value: Variant, message := "") -> void:
	_check(value != null, "expected a non-null value", message)


func assert_has(container: Variant, item: Variant, message := "") -> void:
	_check(container.has(item), "expected %s to contain %s" % [str(container), str(item)], message)


func assert_does_not_have(container: Variant, item: Variant, message := "") -> void:
	var ok: bool = not container.has(item)
	_check(ok, "expected %s not to contain %s" % [str(container), str(item)], message)


func assert_is(value: Variant, type_script: Variant, message := "") -> void:
	var ok := is_instance_of(value, type_script)
	_check(ok, "expected %s to be an instance of %s" % [str(value), str(type_script)], message)


# ---------------------------------------------------------------------------
# Signal watching
# ---------------------------------------------------------------------------


## Starts recording every signal emitted by [param obj].
func watch_signals(obj: Object) -> void:
	var id := obj.get_instance_id()
	_signal_log[id] = {}
	for sig in obj.get_signal_list():
		var sig_name: String = sig["name"]
		var arg_count: int = sig["args"].size()
		_signal_log[id][sig_name] = []
		var recorder := func(a = null, b = null, c = null, d = null, e = null, f = null) -> void:
			var args := [a, b, c, d, e, f].slice(0, mini(arg_count, SIGNAL_ARG_SLOTS))
			if _signal_log.has(id):
				_signal_log[id][sig_name].append(args)
		if arg_count <= SIGNAL_ARG_SLOTS:
			obj.connect(sig_name, recorder)


func get_signal_emit_count(obj: Object, signal_name: String) -> int:
	var id := obj.get_instance_id()
	if not _signal_log.has(id) or not _signal_log[id].has(signal_name):
		return 0
	return _signal_log[id][signal_name].size()


## Returns the arguments of emission [param index] (negative counts from the end).
func get_signal_parameters(obj: Object, signal_name: String, index := -1) -> Array:
	var count := get_signal_emit_count(obj, signal_name)
	if count == 0:
		return []
	var i := index if index >= 0 else count + index
	return _signal_log[obj.get_instance_id()][signal_name][i]


func assert_signal_emitted(obj: Object, signal_name: String, message := "") -> void:
	var count := get_signal_emit_count(obj, signal_name)
	_check(count > 0, "expected signal '%s' to be emitted" % signal_name, message)


func assert_signal_not_emitted(obj: Object, signal_name: String, message := "") -> void:
	var count := get_signal_emit_count(obj, signal_name)
	_check(count == 0, "expected signal '%s' not emitted (%d)" % [signal_name, count], message)


func assert_signal_emit_count(obj: Object, signal_name: String, times: int, message := "") -> void:
	var count := get_signal_emit_count(obj, signal_name)
	var detail := "expected '%s' emitted %d times but was %d" % [signal_name, times, count]
	_check(count == times, detail, message)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------


func _check(ok: bool, detail: String, message: String) -> void:
	_assert_count += 1
	if not ok:
		_record_failure(detail if message.is_empty() else "%s — %s" % [message, detail])


func _record_failure(text: String) -> void:
	_failures.append(text)


static func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		var numeric := [TYPE_INT, TYPE_FLOAT]
		if typeof(a) in numeric and typeof(b) in numeric:
			return is_equal_approx(float(a), float(b))
		return false
	return a == b
