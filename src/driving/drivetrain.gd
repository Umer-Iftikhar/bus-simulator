class_name Drivetrain
extends RefCounted
## Converts pedal input, gear and current speed into engine force and brake.
##
## * Drive (D): the accelerator pushes forward with a torque curve that fades
##   to zero at top speed. Rolling backwards, it brakes first.
## * Reverse (R): the accelerator pushes backwards, limited to a slow reverse
##   top speed. Rolling forwards, it brakes first.
## * The brake pedal always brakes (and holds the bus when stopped).
## * With no pedal input a light rolling resistance stops the bus from creeping.

const REVERSE_TOP_SPEED := 4.0
const REVERSE_FORCE_RATIO := 0.45
const STOPPED_SPEED := 0.6
## Speed below which the gear can be changed.
const GEAR_CHANGE_SPEED := 1.0
const IDLE_BRAKE_RATIO := 0.04
## Fraction of top speed after which engine force fades linearly to zero.
const FADE_START := 0.85
## Steering lock left at top speed, as a fraction of full lock.
const MIN_STEER_RATIO := 0.22


## Returns {"engine_force": float, "brake": float}.
static func compute(
	throttle: float,
	brake_pedal: float,
	forward_speed: float,
	top_speed: float,
	engine_force: float,
	brake_force: float,
	reverse := false
) -> Dictionary:
	var engine := 0.0
	var brake := 0.0
	if brake_pedal > 0.0:
		brake = brake_pedal * brake_force
	elif throttle > 0.0 and not reverse:
		if forward_speed < -STOPPED_SPEED:
			brake = throttle * brake_force
		else:
			engine = throttle * engine_force * torque_curve(forward_speed, top_speed)
	elif throttle > 0.0 and reverse:
		if forward_speed > STOPPED_SPEED:
			brake = throttle * brake_force
		else:
			var room := clampf(1.0 + forward_speed / REVERSE_TOP_SPEED, 0.0, 1.0)
			engine = -throttle * engine_force * REVERSE_FORCE_RATIO * room
	else:
		brake = brake_force * IDLE_BRAKE_RATIO
	return {"engine_force": engine, "brake": brake}


## Fraction of peak force available at [param speed]; 0 at or beyond top speed.
static func torque_curve(speed: float, top_speed: float) -> float:
	if top_speed <= 0.0:
		return 0.0
	var ratio := speed / top_speed
	return clampf((1.0 - ratio) / (1.0 - FADE_START), 0.0, 1.0)


## Steering lock shrinks with speed so the bus stays stable on fast roads.
static func steer_limit(max_steer: float, forward_speed: float, top_speed: float) -> float:
	if top_speed <= 0.0:
		return max_steer
	var ratio := clampf(absf(forward_speed) / top_speed, 0.0, 1.0)
	return max_steer * lerpf(1.0, MIN_STEER_RATIO, ratio)


static func can_change_gear(forward_speed: float) -> bool:
	return absf(forward_speed) < GEAR_CHANGE_SPEED
