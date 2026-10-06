extends TestCase
## Self-tests for the TestCase assertion helpers used by every other suite.

signal pinged(value: int, label: String)


func _probe() -> TestCase:
	var probe := TestCase.new()
	probe._tree = get_tree()
	return probe


func test_passing_assertions_record_no_failures() -> void:
	var probe := _probe()
	probe.assert_true(true)
	probe.assert_false(false)
	probe.assert_eq(3, 3)
	probe.assert_eq(2, 2.0)
	probe.assert_ne("a", "b")
	probe.assert_almost_eq(1.0, 1.05, 0.1)
	probe.assert_gt(5, 4)
	probe.assert_ge(4, 4)
	probe.assert_lt(1, 2)
	probe.assert_le(2, 2)
	probe.assert_between(5, 1, 10)
	probe.assert_null(null)
	probe.assert_not_null(1)
	probe.assert_has([1, 2], 2)
	probe.assert_does_not_have({"a": 1}, "b")
	probe.assert_vec3_almost_eq(Vector3.ONE, Vector3(1, 1, 1.01), 0.1)
	assert_eq(probe._failures.size(), 0, "no failures expected: %s" % str(probe._failures))
	assert_eq(probe._assert_count, 16)


func test_failing_assertions_are_recorded() -> void:
	var probe := _probe()
	probe.assert_true(false)
	probe.assert_eq(1, 2)
	probe.assert_eq("1", 1)
	probe.assert_almost_eq(1.0, 2.0, 0.1)
	probe.assert_between(11, 1, 10)
	probe.assert_has([1], 3)
	probe.fail("explicit")
	assert_eq(probe._failures.size(), 7)


func test_failure_message_includes_custom_text_and_values() -> void:
	var probe := _probe()
	probe.assert_eq(1, 2, "custom context")
	assert_eq(probe._failures.size(), 1)
	assert_true(probe._failures[0].contains("custom context"))
	assert_true(probe._failures[0].contains("expected [2] but got [1]"))


func test_signal_watching_counts_and_captures_arguments() -> void:
	watch_signals(self)
	assert_signal_not_emitted(self, "pinged")
	pinged.emit(1, "one")
	pinged.emit(2, "two")
	assert_signal_emitted(self, "pinged")
	assert_signal_emit_count(self, "pinged", 2)
	assert_eq(get_signal_parameters(self, "pinged"), [2, "two"])
	assert_eq(get_signal_parameters(self, "pinged", 0), [1, "one"])


func test_autofree_releases_nodes_after_cleanup() -> void:
	var probe := _probe()
	var node := Node.new()
	probe.add_child_autofree(node)
	assert_true(node.is_inside_tree())
	probe._cleanup()
	assert_false(is_instance_valid(node))


func test_wait_until_returns_when_predicate_met() -> void:
	var frames := [0]
	var counter := func() -> void: frames[0] += 1
	get_tree().physics_frame.connect(counter)
	var met := await wait_until(func() -> bool: return frames[0] >= 3, 1.0)
	get_tree().physics_frame.disconnect(counter)
	assert_true(met)
	assert_between(frames[0], 3, 4)


func test_wait_until_times_out() -> void:
	var met := await wait_until(func() -> bool: return false, 0.1)
	assert_false(met)
