class_name MirrorRig
extends Node3D
## Functional mirrors: each mirror is a low-resolution SubViewport whose camera
## sits at the mirror and looks backwards, rendering the real scene.
##
## Mirrors are the most GPU-hungry feature in the game (one extra scene render
## per mirror), so resolutions are deliberately tiny and [member refresh_interval]
## can thin out updates on weak devices (1 = every frame, 3 = every third frame).
## A shattered mirror stops rendering altogether.

const LEFT := DamageModel.MIRROR_LEFT
const RIGHT := DamageModel.MIRROR_RIGHT
const REAR := "mirror_rear"
const VIEWS := [LEFT, RIGHT, REAR]
const SIDE_RESOLUTION := Vector2i(160, 120)
const REAR_RESOLUTION := Vector2i(256, 96)
## Upper bound on mirror pixels rendered per frame (performance budget).
const PIXEL_BUDGET := 80000
## Side mirrors angle slightly outward so they show the lane, not just the bus.
const SIDE_OUTWARD_ANGLE := 0.14

var bus: Bus
var refresh_interval := 1
var viewports := {}
var cameras := {}
var broken := {}
var _frame := 0


static func create(target: Bus, interval := 1) -> MirrorRig:
	var rig := MirrorRig.new()
	rig.name = "Mirrors"
	rig.bus = target
	rig.refresh_interval = maxi(interval, 1)
	rig._build()
	return rig


func _build() -> void:
	for view in VIEWS:
		var viewport := SubViewport.new()
		viewport.name = "View_" + view
		viewport.size = REAR_RESOLUTION if view == REAR else SIDE_RESOLUTION
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.positional_shadow_atlas_size = 0
		var camera := Camera3D.new()
		camera.name = "Camera"
		camera.fov = 55.0 if view == REAR else 38.0
		camera.near = 0.3
		camera.far = 250.0
		viewport.add_child(camera)
		add_child(viewport)
		viewports[view] = viewport
		cameras[view] = camera
		broken[view] = false


func _ready() -> void:
	for view in VIEWS:
		(cameras[view] as Camera3D).current = true
	_place_cameras()


func texture(view: String) -> ViewportTexture:
	return (viewports[view] as SubViewport).get_texture()


func set_broken(view: String, is_broken: bool) -> void:
	broken[view] = is_broken
	_apply_update_modes()


## True while the mirror is live (not shattered). With a reduced refresh rate a
## live mirror still skips some frames; see [method should_refresh].
func is_rendering(view: String) -> bool:
	return not broken[view]


## Pixels rendered when every mirror updates.
static func total_pixels() -> int:
	return SIDE_RESOLUTION.x * SIDE_RESOLUTION.y * 2 + REAR_RESOLUTION.x * REAR_RESOLUTION.y


## Whether mirrors refresh on [param frame] given a refresh interval.
static func should_refresh(frame: int, interval: int) -> bool:
	return interval <= 1 or frame % interval == 0


## Global transform for a mirror camera given the bus's transform.
static func camera_transform(view: String, bus_xform: Transform3D, spec: BusSpec) -> Transform3D:
	var local: Transform3D
	if view == REAR:
		var eye := Vector3(0.0, spec.height - 0.3, -spec.length / 2.0 - 0.1)
		# Camera looks down its -Z; the bus's backward direction is -Z too.
		local = Transform3D(Basis(Vector3.RIGHT, -0.08), eye)
	else:
		var side := 1.0 if view == LEFT else -1.0
		var eye := Bus.mirror_mount(spec, view)
		# Rotating -Z about +Y by -angle swings the view toward +X (the bus's left).
		local = Transform3D(Basis(Vector3.UP, -side * SIDE_OUTWARD_ANGLE), eye)
	return bus_xform * local


func _process(_delta: float) -> void:
	_frame += 1
	_place_cameras()
	_apply_update_modes()


func _place_cameras() -> void:
	if not is_instance_valid(bus) or not bus.is_inside_tree():
		return
	for view in VIEWS:
		(cameras[view] as Camera3D).global_transform = camera_transform(
			view, bus.global_transform, bus.spec
		)


func _apply_update_modes() -> void:
	var refresh := should_refresh(_frame, refresh_interval)
	for view in VIEWS:
		var viewport := viewports[view] as SubViewport
		if broken[view]:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		elif refresh_interval <= 1:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif refresh:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
