extends TestCase
## The Android export must install on every phone: 64- and 32-bit ARM builds,
## and one permanent signing key so new versions install over old ones.

const PRESETS := "res://export_presets.cfg"
const KEYSTORE := "res://tools/android/debug.keystore"
const SCRIPT := "res://tools/export_android.sh"


func _preset() -> ConfigFile:
	var config := ConfigFile.new()
	assert_eq(config.load(PRESETS), OK)
	return config


func test_builds_for_64_and_32_bit_arm_phones() -> void:
	var config := _preset()
	assert_true(config.get_value("preset.0.options", "architectures/arm64-v8a"))
	assert_true(
		config.get_value("preset.0.options", "architectures/armeabi-v7a"),
		"32-bit Android phones reject arm64-only APKs as invalid"
	)


func test_apk_is_signed() -> void:
	assert_true(_preset().get_value("preset.0.options", "package/signed"))


func test_permanent_debug_key_is_committed_and_used() -> void:
	assert_true(FileAccess.file_exists(KEYSTORE), "stable key ships with the repo")
	assert_gt(FileAccess.get_file_as_bytes(KEYSTORE).size(), 1000)
	var script := FileAccess.get_file_as_string(SCRIPT)
	assert_true(script.contains("tools/android/debug.keystore"), "tools/android/debug.keystore")
	assert_false(script.contains("keytool -genkeypair"), "no throwaway key per build")


func test_export_script_verifies_both_architectures_and_signature() -> void:
	var script := FileAccess.get_file_as_string(SCRIPT)
	assert_true(script.contains("lib/armeabi-v7a/"), "lib/armeabi-v7a/")
	assert_true(script.contains("lib/arm64-v8a/"), "lib/arm64-v8a/")
	assert_true(script.contains("Verified using $scheme scheme"), "Verified using $scheme scheme")
