class_name DriveInput
extends RefCounted
## Smoothed driver controls.
##
## * Pedals ramp in quickly (no instant jolts) and release a little faster.
## * Steering uses a response curve (gentle near centre, full lock at the end),
##   eases toward the target instead of snapping, turns more slowly at speed,
##   and self-centres when released, like a real power-steered bus.

## Pedal travel per second when pressing / releasing.
const PEDAL_RATE := 4.0
const PEDAL_RELEASE_RATE := 6.0
## >1 makes small steering inputs gentler for fine lane control.
const RESPONSE_EXPONENT := 1.5
## Exponential easing toward the steering target (1/s).
const STEER_EASING := 9.0
## Steering speed left at top speed, as a fraction of the standstill rate.
const HIGH_SPEED_STEER_RATE := 0.55

var throttle := 0.0
var brake := 0.0
var steer := 0.0
## Maximum steering travel per second when turning (full lock = 1.0).
var steer_rate := 2.0
## Maximum self-centring speed per second when no steering is requested.
var return_rate := 2.5


## [param speed_ratio] is current speed / top speed (0..1).
func update(
	target_throttle: float,
	target_brake: float,
	target_steer: float,
	delta: float,
	speed_ratio := 0.0
) -> void:
	throttle = _pedal(throttle, clampf(target_throttle, 0.0, 1.0), delta)
	brake = _pedal(brake, clampf(target_brake, 0.0, 1.0), delta)
	var target := shape_steer(clampf(target_steer, -1.0, 1.0))
	var rate := return_rate if is_zero_approx(target) else steer_rate
	rate *= lerpf(1.0, HIGH_SPEED_STEER_RATE, clampf(speed_ratio, 0.0, 1.0))
	var eased := (target - steer) * (1.0 - exp(-STEER_EASING * delta))
	var max_step := rate * delta
	steer = clampf(steer + clampf(eased, -max_step, max_step), -1.0, 1.0)
	if absf(target - steer) < 0.001:
		steer = target


## Response curve: keeps sign, softens small inputs, preserves full lock.
static func shape_steer(value: float) -> float:
	return signf(value) * pow(absf(value), RESPONSE_EXPONENT)


func reset() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0


static func _pedal(current: float, target: float, delta: float) -> float:
	var rate := PEDAL_RATE if target > current else PEDAL_RELEASE_RATE
	return move_toward(current, target, rate * delta)
