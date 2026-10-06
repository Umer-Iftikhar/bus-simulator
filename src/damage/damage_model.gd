class_name DamageModel
extends RefCounted
## Localized bus damage. The bus is a set of hittable parts, each with its own
## health (0..1), feeding a weighted overall health:
##   * 0 overall health -> the bus is wrecked and cannot be driven;
##   * above 0 -> top speed drops proportionally with health;
##   * mirrors shatter on any real knock (their state drives mirror visibility).

signal changed
signal part_damaged(part: String, health: float)
signal mirror_shattered(part: String)
signal wrecked

const BODY_FRONT := "body_front"
const BODY_REAR := "body_rear"
const BODY_LEFT := "body_left"
const BODY_RIGHT := "body_right"
const MIRROR_LEFT := "mirror_left"
const MIRROR_RIGHT := "mirror_right"
const PARTS := [BODY_FRONT, BODY_REAR, BODY_LEFT, BODY_RIGHT, MIRROR_LEFT, MIRROR_RIGHT]
const MIRRORS := [MIRROR_LEFT, MIRROR_RIGHT]
const WEIGHTS := {
	BODY_FRONT: 0.3,
	BODY_REAR: 0.2,
	BODY_LEFT: 0.22,
	BODY_RIGHT: 0.22,
	MIRROR_LEFT: 0.03,
	MIRROR_RIGHT: 0.03,
}
## Per-physics-step velocity change (m/s) below which contact is just scraping.
const MIN_IMPACT := 0.5
## Health lost per m/s of impact on a body panel.
const DAMAGE_PER_MS := 0.04
## Any impact this hard breaks a mirror outright.
const MIRROR_BREAK := 0.8
## Overall health at or below this is a wreck (all panels effectively gone).
const WRECK_THRESHOLD := 0.08
## Top speed left at the brink of being wrecked.
const MIN_SPEED_FACTOR := 0.4
## Mirror height band and how close to the front they sit (bus-local metres).
const MIRROR_ZONE_DEPTH := 1.2

var parts := {}
var _was_wrecked := false


func _init() -> void:
	for part in PARTS:
		parts[part] = 1.0


static func from_dict(data: Dictionary) -> DamageModel:
	var model := DamageModel.new()
	for part in PARTS:
		if data.has(part):
			model.parts[part] = clampf(float(data[part]), 0.0, 1.0)
	model._was_wrecked = model.is_wrecked()
	return model


## Only damaged parts are stored, so a pristine bus serialises to {}.
func to_dict() -> Dictionary:
	var data := {}
	for part in PARTS:
		if parts[part] < 1.0:
			data[part] = parts[part]
	return data


func health(part: String) -> float:
	return parts.get(part, 1.0)


func overall() -> float:
	var total := 0.0
	for part in PARTS:
		total += parts[part] * WEIGHTS[part]
	return total


func health_percent() -> int:
	return roundi(overall() * 100.0)


func is_pristine() -> bool:
	for part in PARTS:
		if parts[part] < 1.0:
			return false
	return true


func is_wrecked() -> bool:
	return overall() <= WRECK_THRESHOLD


func is_mirror_broken(part: String) -> bool:
	return part in MIRRORS and parts[part] <= 0.0


## Top-speed multiplier: 1.0 when healthy, falling linearly toward MIN_SPEED_FACTOR.
func speed_factor() -> float:
	var usable := clampf((overall() - WRECK_THRESHOLD) / (1.0 - WRECK_THRESHOLD), 0.0, 1.0)
	return lerpf(MIN_SPEED_FACTOR, 1.0, usable)


## Applies a hit of [param impact_speed] m/s to [param part]. Returns health lost.
func apply_impact(part: String, impact_speed: float) -> float:
	if not parts.has(part) or impact_speed < MIN_IMPACT:
		return 0.0
	var before: float = parts[part]
	if part in MIRRORS:
		if impact_speed >= MIRROR_BREAK:
			parts[part] = 0.0
	else:
		parts[part] = maxf(0.0, before - impact_speed * DAMAGE_PER_MS)
	var lost: float = before - parts[part]
	if lost <= 0.0:
		return 0.0
	part_damaged.emit(part, parts[part])
	if part in MIRRORS:
		mirror_shattered.emit(part)
	changed.emit()
	if is_wrecked() and not _was_wrecked:
		_was_wrecked = true
		wrecked.emit()
	return lost


func repair() -> void:
	for part in PARTS:
		parts[part] = 1.0
	_was_wrecked = false
	changed.emit()


## Cost to restore everything: panel work scales with how pricey the bus is,
## plus a flat price per broken mirror.
func repair_cost(bus_id: String) -> int:
	var rate := 600.0 + Catalog.bus_price(bus_id) * 0.08
	var cost := 0.0
	for part in PARTS:
		if part in MIRRORS:
			cost += 0.0 if parts[part] > 0.0 else 120.0
		else:
			cost += (1.0 - parts[part]) * WEIGHTS[part] * rate * 4.0
	return int(ceil(cost / 10.0)) * 10


## Which part a contact belongs to, from the contact point and the contact
## normal (pointing into the bus), both in bus-local coordinates (+Z forward,
## +X left). The normal decides the face; the point decides mirror hits.
static func part_for_contact(local_point: Vector3, local_normal: Vector3, spec: BusSpec) -> String:
	if absf(local_normal.z) >= absf(local_normal.x):
		return BODY_FRONT if local_normal.z < 0.0 else BODY_REAR
	var left_side := local_normal.x < 0.0
	var near_front := local_point.z > spec.length / 2.0 - MIRROR_ZONE_DEPTH
	var mirror_height := local_point.y > spec.height * 0.45
	if near_front and mirror_height:
		return MIRROR_LEFT if left_side else MIRROR_RIGHT
	return BODY_LEFT if left_side else BODY_RIGHT
