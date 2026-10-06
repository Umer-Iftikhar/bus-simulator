extends TestCase


func test_synthesized_horn_has_expected_format_and_length() -> void:
	var wav := Horn.synthesize()
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(wav.mix_rate, Horn.MIX_RATE)
	assert_false(wav.stereo)
	assert_eq(wav.data.size(), int(Horn.MIX_RATE * Horn.DURATION) * 2)
	assert_almost_eq(wav.get_length(), Horn.DURATION, 0.01)


func test_horn_is_audible_and_fades_in() -> void:
	var data := Horn.synthesize().data
	var peak := 0
	for i in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(i)))
	assert_gt(peak, 8000, "horn should be loud")
	assert_eq(data.decode_s16(0), 0, "envelope starts silent (no click)")
