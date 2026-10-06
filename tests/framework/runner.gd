extends SceneTree
## Headless test runner.
##
## Usage:
##   godot --headless --fixed-fps 60 -s res://tests/framework/runner.gd -- \
##       --suite=unit|integration|system|all [--filter=text] [--junit=res://reports/x.xml]
##
## Discovers `test_*.gd` files under res://tests/<suite>/, runs every `test_*`
## method, prints a report, optionally writes JUnit XML and a GitHub job
## summary, and exits with code 1 when anything failed.

const SUITES := ["unit", "integration", "system"]

var _suite := "all"
var _filter := ""
var _junit_path := ""
var _results: Array[Dictionary] = []


func _init() -> void:
	_parse_args()
	_run.call_deferred()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			_suite = arg.trim_prefix("--suite=")
		elif arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
		elif arg.begins_with("--junit="):
			_junit_path = arg.trim_prefix("--junit=")


func _run() -> void:
	var suites: Array = SUITES if _suite == "all" else [_suite]
	var started := Time.get_ticks_msec()
	for suite in suites:
		var files := _discover("res://tests/%s" % suite)
		print("\n=== Suite: %s (%d files) ===" % [suite, files.size()])
		for path in files:
			await _run_file(suite, path)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	var failed := _print_report(elapsed)
	if not _junit_path.is_empty():
		_write_junit()
	_write_github_summary(elapsed)
	quit(1 if failed > 0 or _results.is_empty() else 0)


func _discover(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_discover(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	found.sort()
	return found


func _run_file(suite: String, path: String) -> void:
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		_results.append(_result(suite, path, "<load>", ["could not load test script"], 0.0))
		return
	var instance: TestCase = script.new()
	instance._tree = self
	var methods := _test_methods(script)
	if methods.is_empty():
		instance._cleanup()
		return
	print("-- %s" % path.trim_prefix("res://tests/"))
	await instance.before_all()
	for method in methods:
		var t0 := Time.get_ticks_usec()
		instance._failures = []
		instance._assert_count = 0
		await instance.before_each()
		await instance.call(method)
		await instance.after_each()
		instance._cleanup()
		await process_frame
		var failures := instance._failures.duplicate()
		if instance._assert_count == 0:
			failures.append("test made no assertions")
		var seconds := (Time.get_ticks_usec() - t0) / 1_000_000.0
		_results.append(_result(suite, path, method, failures, seconds))
		var status := "PASS" if failures.is_empty() else "FAIL"
		print("   [%s] %s (%.3fs)" % [status, method, seconds])
		for failure in failures:
			print("          ✗ %s" % failure)
	await instance.after_all()
	instance._cleanup()


func _test_methods(script: GDScript) -> PackedStringArray:
	var names := PackedStringArray()
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_") or names.has(method_name):
			continue
		if not _filter.is_empty() and not method_name.contains(_filter):
			continue
		names.append(method_name)
	return names


func _result(suite: String, path: String, method: String, failures, seconds: float) -> Dictionary:
	return {
		"suite": suite,
		"file": path.get_file().get_basename(),
		"name": method,
		"failures": failures,
		"time": seconds,
	}


func _print_report(elapsed: float) -> int:
	var failed := _results.filter(func(r): return not r["failures"].is_empty()).size()
	print("\n==============================================")
	print(
		(
			"Tests: %d  Passed: %d  Failed: %d  Time: %.2fs"
			% [_results.size(), _results.size() - failed, failed, elapsed]
		)
	)
	if _results.is_empty():
		print("No tests were found — treating as failure.")
	for r in _results:
		if not r["failures"].is_empty():
			print("FAILED %s/%s::%s" % [r["suite"], r["file"], r["name"]])
	print("==============================================")
	return failed


func _write_junit() -> void:
	var by_file := {}
	for r in _results:
		var key := "%s.%s" % [r["suite"], r["file"]]
		if not by_file.has(key):
			by_file[key] = []
		by_file[key].append(r)
	var xml := PackedStringArray(['<?xml version="1.0" encoding="UTF-8"?>', "<testsuites>"])
	for key in by_file:
		var cases: Array = by_file[key]
		var fails := cases.filter(func(r): return not r["failures"].is_empty()).size()
		var total_time := 0.0
		for r in cases:
			total_time += r["time"]
		xml.append(
			(
				'  <testsuite name="%s" tests="%d" failures="%d" time="%.3f">'
				% [key, cases.size(), fails, total_time]
			)
		)
		for r in cases:
			xml.append(
				'    <testcase classname="%s" name="%s" time="%.3f">' % [key, r["name"], r["time"]]
			)
			for failure in r["failures"]:
				xml.append('      <failure message="%s"/>' % _xml_escape(failure))
			xml.append("    </testcase>")
		xml.append("  </testsuite>")
	xml.append("</testsuites>")
	DirAccess.make_dir_recursive_absolute(_junit_path.get_base_dir())
	var file := FileAccess.open(_junit_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write JUnit report to %s" % _junit_path)
		return
	file.store_string("\n".join(xml) + "\n")


func _write_github_summary(elapsed: float) -> void:
	var summary_path := OS.get_environment("GITHUB_STEP_SUMMARY")
	if summary_path.is_empty():
		return
	var file := FileAccess.open(summary_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	var failed := _results.filter(func(r): return not r["failures"].is_empty())
	var icon := "✅" if failed.is_empty() else "❌"
	file.store_line("### %s %s tests" % [icon, _suite])
	file.store_line(
		(
			"%d run, %d passed, %d failed in %.2fs\n"
			% [_results.size(), _results.size() - failed.size(), failed.size(), elapsed]
		)
	)
	file.store_line("| Suite | File | Tests | Failed |")
	file.store_line("|---|---|---|---|")
	var rows := {}
	for r in _results:
		var key := "%s|%s" % [r["suite"], r["file"]]
		if not rows.has(key):
			rows[key] = [0, 0]
		rows[key][0] += 1
		if not r["failures"].is_empty():
			rows[key][1] += 1
	for key in rows:
		var parts: PackedStringArray = key.split("|")
		file.store_line("| %s | %s | %d | %d |" % [parts[0], parts[1], rows[key][0], rows[key][1]])
	for r in failed:
		file.store_line("\n**%s::%s**" % [r["file"], r["name"]])
		for failure in r["failures"]:
			file.store_line("- %s" % failure)


static func _xml_escape(text: String) -> String:
	return text.xml_escape(true)
