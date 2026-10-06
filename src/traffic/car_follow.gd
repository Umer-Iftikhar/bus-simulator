class_name CarFollow
extends RefCounted
## Intelligent Driver Model (IDM): smooth, collision-free car following.
## Free road -> accelerate toward the desired speed; closing on a leader ->
## brake so the gap never drops below [member min_gap] + speed * [member headway].

const EXPONENT := 4.0
## Hard limit on braking (emergency stop), m/s².
const MAX_DECEL := 9.0

var max_accel := 1.6
var comfort_decel := 2.2
var min_gap := 3.0
var headway := 1.3


## Acceleration for a car at [param speed] wanting [param desired_speed] with
## [param gap] metres (bumper to bumper) to a leader doing [param leader_speed].
## Pass INF as the gap for a free road.
func acceleration(speed: float, desired_speed: float, gap: float, leader_speed: float) -> float:
	var free_term := 1.0
	if desired_speed > 0.0:
		free_term = 1.0 - pow(maxf(speed, 0.0) / desired_speed, EXPONENT)
	var interaction := 0.0
	if gap < INF:
		var closing := speed - leader_speed
		var desired_gap := (
			min_gap
			+ maxf(0.0, speed * headway + speed * closing / (2.0 * sqrt(max_accel * comfort_decel)))
		)
		interaction = pow(desired_gap / maxf(gap, 0.1), 2.0)
	return clampf(max_accel * (free_term - interaction), -MAX_DECEL, max_accel)
