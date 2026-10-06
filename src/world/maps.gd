class_name Maps
extends RefCounted
## Registry of every map shipped with the game. All maps are open from the start.


static func all() -> Array[MapDef]:
	return [harbor()]


static func get_map(map_id: String) -> MapDef:
	for map in all():
		if map.id == map_id:
			return map
	return null


static func ids() -> PackedStringArray:
	var result := PackedStringArray()
	for map in all():
		result.append(map.id)
	return result


static func harbor() -> MapDef:
	var map := MapDef.new()
	map.id = "harbor"
	map.display_name = "Harbor Loop"
	map.description = "A gentle coastal town loop. Wide bends, calm traffic."
	map.fare = 12
	map.scenery_seed = 11
	map.points = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(150, 0),
			Vector2(260, 40),
			Vector2(300, 140),
			Vector2(260, 250),
			Vector2(150, 300),
			Vector2(40, 320),
			Vector2(-80, 280),
			Vector2(-140, 180),
			Vector2(-120, 70),
			Vector2(-60, 10),
		]
	)
	map.stops = [0.02, 0.17, 0.33, 0.5, 0.66, 0.82, 0.96]
	map.traffic_cars = 8
	map.ground_color = Color(0.82, 0.76, 0.58)
	map.sky_top = Color(0.3, 0.55, 0.9)
	map.sky_horizon = Color(0.78, 0.88, 0.95)
	map.building_colors = [Color(0.95, 0.93, 0.88), Color(0.55, 0.75, 0.85), Color(0.95, 0.75, 0.6)]
	map.building_height = Vector2(5, 12)
	map.building_spacing = 30.0
	map.tree_chance = 0.35
	map.tree_color = Color(0.25, 0.55, 0.3)
	map.has_water = true
	return map
