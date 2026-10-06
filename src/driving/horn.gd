class_name Horn
extends AudioStreamPlayer3D
## Two-tone bus horn synthesised at startup (no audio assets required).

const MIX_RATE := 22050
const DURATION := 0.6
const TONES := [311.0, 392.0]


func _init() -> void:
	name = "Horn"
	stream = synthesize()
	unit_size = 20.0


func honk() -> void:
	play()


static func synthesize() -> AudioStreamWAV:
	var frames := int(MIX_RATE * DURATION)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / MIX_RATE
		var envelope := minf(1.0, minf(t * 40.0, (DURATION - t) * 20.0))
		var sample := 0.0
		for tone in TONES:
			sample += signf(sin(TAU * tone * t)) * 0.22
		data.encode_s16(i * 2, int(clampf(sample * envelope, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
