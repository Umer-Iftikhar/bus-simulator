class_name Maps
extends RefCounted
## Registry of every map shipped with the game. All maps are open from the start.


static func all() -> Array[MapDef]:
	return [harbor(), desert(), downtown(), pines()]


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


static func desert() -> MapDef:
	var map := MapDef.new()
	map.id = "desert"
	map.display_name = "Desert Highway"
	map.description = "Long sun-baked straights between adobe towns. Tempting to speed."
	map.fare = 15
	map.scenery_seed = 23
	map.points = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(400, 0),
			Vector2(520, 60),
			Vector2(540, 180),
			Vector2(450, 260),
			Vector2(150, 270),
			Vector2(-100, 250),
			Vector2(-180, 150),
			Vector2(-120, 30),
		]
	)
	map.stops = [0.02, 0.2, 0.4, 0.6, 0.8, 0.97]
	map.traffic_cars = 6
	map.ground_color = Color(0.86, 0.7, 0.46)
	map.sky_top = Color(0.35, 0.6, 0.95)
	map.sky_horizon = Color(0.98, 0.88, 0.7)
	map.building_colors = [Color(0.85, 0.6, 0.4), Color(0.9, 0.78, 0.6), Color(0.75, 0.5, 0.35)]
	map.building_height = Vector2(4, 8)
	map.building_spacing = 55.0
	map.tree_chance = 0.2
	map.tree_color = Color(0.35, 0.5, 0.25)
	map.sun_elevation = 65.0
	return map


static func downtown() -> MapDef:
	var map := MapDef.new()
	map.id = "downtown"
	map.display_name = "Downtown"
	map.description = "Dense towers, tight corners and heavy traffic. The best fares in town."
	map.fare = 20
	map.scenery_seed = 37
	map.points = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(200, 0),
			Vector2(235, 35),
			Vector2(235, 165),
			Vector2(200, 200),
			Vector2(130, 200),
			Vector2(95, 235),
			Vector2(95, 300),
			Vector2(60, 335),
			Vector2(-60, 335),
			Vector2(-95, 300),
			Vector2(-95, 35),
			Vector2(-60, 0),
		]
	)
	map.stops = [0.02, 0.15, 0.29, 0.43, 0.57, 0.71, 0.85, 0.97]
	map.traffic_cars = 12
	map.ground_color = Color(0.42, 0.42, 0.44)
	map.sky_top = Color(0.4, 0.55, 0.75)
	map.sky_horizon = Color(0.8, 0.82, 0.85)
	map.building_colors = [
		Color(0.55, 0.6, 0.68),
		Color(0.7, 0.7, 0.72),
		Color(0.45, 0.48, 0.55),
		Color(0.8, 0.75, 0.65)
	]
	map.building_height = Vector2(18, 45)
	map.building_spacing = 22.0
	map.tree_chance = 0.08
	map.tree_color = Color(0.25, 0.45, 0.25)
	map.sun_elevation = 40.0
	return map


static func pines() -> MapDef:
	var map := MapDef.new()
	map.id = "pines"
	map.display_name = "Pine Hills by Night"
	map.description = "A winding forest loop after dark. Headlights on, mirrors matter."
	map.fare = 16
	map.scenery_seed = 41
	map.points = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(120, -40),
			Vector2(240, 0),
			Vector2(300, 100),
			Vector2(260, 200),
			Vector2(320, 300),
			Vector2(220, 380),
			Vector2(80, 340),
			Vector2(0, 260),
			Vector2(-80, 180),
			Vector2(-60, 80),
		]
	)
	map.stops = [0.02, 0.19, 0.37, 0.55, 0.75, 0.97]
	map.traffic_cars = 5
	map.ground_color = Color(0.16, 0.26, 0.15)
	map.sky_top = Color(0.02, 0.03, 0.09)
	map.sky_horizon = Color(0.1, 0.12, 0.22)
	map.building_colors = [Color(0.45, 0.32, 0.22), Color(0.55, 0.5, 0.42)]
	map.building_height = Vector2(4, 7)
	map.building_spacing = 26.0
	map.tree_chance = 0.75
	map.tree_color = Color(0.1, 0.3, 0.15)
	map.sun_elevation = 20.0
	map.night = true
	map.conifers = true
	return map
