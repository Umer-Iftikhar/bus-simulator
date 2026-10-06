class_name FlatWorld
extends Node3D
## Test fixture: a large flat collision floor for physics integration tests.


static func create(size := 4000.0) -> FlatWorld:
	var world := FlatWorld.new()
	world.name = "FlatWorld"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	shape.shape = box
	shape.position.y = -1.0
	floor_body.add_child(shape)
	world.add_child(floor_body)
	return world


## Adds a bus at the origin facing +Z and waits for the suspension to settle.
func spawn_bus(test: TestCase, spec := BusSpec.new(), at := Vector3(0, 0.3, 0)) -> Bus:
	var bus := Bus.create(spec)
	add_child(bus)
	bus.global_position = at
	await test.wait_seconds(1.5)
	return bus
