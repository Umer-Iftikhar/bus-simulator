class_name DriveInput
extends RefCounted
## Smoothed driver controls. Pedals respond immediately; the steering wheel turns
## at a finite rate and self-centres when released, like a real power-steered bus.

var throttle := 0.0
var brake := 0.0
var steer := 0.0
## Steering travel per second when the driver turns the wheel (full lock = 1.0).
var steer_rate := 2.0
## Self-centring speed per second when no steering is requested.
var return_rate := 3.0


func update(target_throttle: float, target_brake: float, target_steer: float, delta: float) -> void:
	throttle = clampf(target_throttle, 0.0, 1.0)
	brake = clampf(target_brake, 0.0, 1.0)
	var target := clampf(target_steer, -1.0, 1.0)
	var rate := return_rate if is_zero_approx(target) else steer_rate
	steer = move_toward(steer, target, rate * delta)


func reset() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
