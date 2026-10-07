class_name Maps
extends RefCounted
## Registry of every map shipped with the game. All maps are open from the start.
## Layouts are inspired by real cities (not to scale): long loops with
## bridges, hills and recognisable landmarks.


static func all() -> Array[MapDef]:
	return [islamabad(), washington(), rawalakot(), tokyo(), new_york()]


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


static func _pts(values: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in values:
		out.append(Vector2(v[0], v[1]))
	return out


static func islamabad() -> MapDef:
	var map := MapDef.new()
	map.id = "islamabad"
	map.display_name = "Islamabad"
	map.description = "Wide green boulevards rising toward the Margalla Hills and Faisal Mosque."
	map.fare = 12
	map.scenery_seed = 7
	map.points = _pts(
		[
			[40, 0],
			[600, 0],
			[680, 40],
			[700, 120],
			[700, 450],
			[700, 700],
			[660, 780],
			[580, 800],
			[350, 820],
			[120, 800],
			[40, 770],
			[0, 700],
			[-20, 580],
			[-20, 450],
			[0, 300],
			[-10, 140],
			[-5, 50],
		]
	)
	map.heights = PackedFloat32Array([0, 0, 0, 1, 10, 18, 21, 22, 22, 22, 21, 18, 14, 10, 6, 1, 0])
	map.stops = [0.02, 0.21, 0.4, 0.59, 0.78, 0.97]
	map.stop_names = PackedStringArray(
		[
			"Zero Point",
			"Blue Area",
			"Jinnah Avenue",
			"Faisal Mosque",
			"F-6 Markaz",
			"Zero Point Terminal",
		]
	)
	map.traffic_cars = 13
	map.style = "islamabad"
	map.ground_color = Color(0.36, 0.5, 0.27)
	map.sky_top = Color(0.28, 0.5, 0.88)
	map.sky_horizon = Color(0.8, 0.86, 0.92)
	map.building_colors = [
		Color(0.92, 0.9, 0.85),
		Color(0.85, 0.8, 0.7),
		Color(0.75, 0.82, 0.85),
		Color(0.95, 0.93, 0.9)
	]
	map.floors = Vector2i(3, 9)
	map.block_length = Vector2(70, 110)
	map.tree_chance = 0.25
	map.tree_color = Color(0.22, 0.45, 0.2)
	map.terrain_slope = Vector2(0.0, 0.026)
	map.terrain_amplitude = 4.0
	map.landmarks = [{"type": "mosque", "at": Vector2(350, 1000), "rotation": 0.0}]
	map.parks = [Rect2(200, 150, 300, 200)]
	map.backdrop = "hills_north"
	map.backdrop_height = 420.0
	map.sun_elevation = 55.0
	return map


static func washington() -> MapDef:
	var map := MapDef.new()
	map.id = "washington"
	map.display_name = "Washington, D.C."
	map.description = "Classical avenues, the National Mall and two bridges over the Potomac."
	map.fare = 15
	map.scenery_seed = 13
	map.points = _pts(
		[
			[0, 0],
			[400, 0],
			[480, 40],
			[500, 140],
			[500, 450],
			[470, 530],
			[380, 560],
			[60, 560],
			[-60, 560],
			[-200, 560],
			[-400, 560],
			[-540, 560],
			[-610, 520],
			[-630, 420],
			[-630, 150],
			[-610, 60],
			[-540, 20],
			[-400, 20],
			[-200, 20],
			[-60, 20],
		]
	)
	map.heights = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 6, 6, 0])
	map.stops = [0.02, 0.21, 0.4, 0.641, 0.78, 0.99]
	map.stop_names = PackedStringArray(
		[
			"Union Station",
			"Capitol Hill",
			"Smithsonian",
			"Arlington",
			"Pentagon City",
			"Union Station Terminal",
		]
	)
	map.traffic_cars = 15
	map.style = "washington"
	map.ground_color = Color(0.4, 0.52, 0.3)
	map.sky_top = Color(0.32, 0.55, 0.9)
	map.sky_horizon = Color(0.82, 0.86, 0.9)
	map.building_colors = [
		Color(0.93, 0.91, 0.86),
		Color(0.86, 0.82, 0.74),
		Color(0.78, 0.7, 0.62),
		Color(0.95, 0.95, 0.93)
	]
	map.floors = Vector2i(3, 8)
	map.block_length = Vector2(70, 100)
	map.tree_chance = 0.2
	map.rivers = [{"points": _pts([[-300, -900], [-305, 400], [-300, 1500]]), "width": 150.0}]
	map.bridges = [Vector2i(9, 10), Vector2i(17, 18)]
	map.bridge_style = "arch"
	map.landmarks = [
		{"type": "obelisk", "at": Vector2(250, 280), "rotation": 0.0},
		{"type": "capitol", "at": Vector2(110, 300), "rotation": PI / 2.0},
		{"type": "reflecting_pool", "at": Vector2(180, 280), "rotation": 0.0},
	]
	map.parks = [Rect2(60, 160, 360, 240)]
	map.backdrop = "skyline"
	map.backdrop_height = 70.0
	map.sun_elevation = 48.0
	return map


static func rawalakot() -> MapDef:
	var map := MapDef.new()
	map.id = "rawalakot"
	map.display_name = "Rawalakot"
	map.description = "A mountain town loop: steep climbs, pine forests and the Banjosa valley."
	map.fare = 16
	map.scenery_seed = 29
	map.points = _pts(
		[
			[0, 0],
			[200, -40],
			[380, -20],
			[520, 60],
			[600, 200],
			[580, 360],
			[480, 460],
			[520, 600],
			[640, 700],
			[600, 860],
			[440, 920],
			[280, 880],
			[160, 780],
			[60, 650],
			[-80, 560],
			[-200, 480],
			[-260, 340],
			[-220, 200],
			[-120, 80],
		]
	)
	map.heights = PackedFloat32Array(
		[0, 4, 10, 18, 28, 38, 46, 54, 60, 58, 50, 40, 30, 22, 16, 16, 12, 8, 3]
	)
	map.stops = [0.02, 0.24, 0.45, 0.7, 0.97]
	map.stop_names = PackedStringArray(
		[
			"Rawalakot Bazaar",
			"Khaigala",
			"Hill Top",
			"Banjosa Lake",
			"Bazaar Terminal",
		]
	)
	map.traffic_cars = 8
	map.style = "rawalakot"
	map.ground_color = Color(0.25, 0.42, 0.2)
	map.sky_top = Color(0.25, 0.48, 0.85)
	map.sky_horizon = Color(0.75, 0.83, 0.9)
	map.cloud_cover = 0.55
	map.building_colors = [
		Color(0.9, 0.86, 0.78),
		Color(0.75, 0.6, 0.45),
		Color(0.85, 0.85, 0.82),
		Color(0.6, 0.5, 0.4)
	]
	map.floors = Vector2i(1, 3)
	map.block_length = Vector2(40, 70)
	map.side_streets = false
	map.tree_chance = 0.55
	map.tree_color = Color(0.12, 0.32, 0.16)
	map.conifers = true
	map.terrain_amplitude = 140.0
	map.terrain_slope = Vector2(0.0, 0.06)
	map.water_level = -4.0
	map.river_bed = -9.0
	map.rivers = [
		{
			"points": _pts([[-520, 960], [-320, 720], [-140, 520], [40, 470], [150, 430]]),
			"width": 40.0,
		}
	]
	map.lakes = [{"center": Vector2(200, 420), "radius": 85.0}]
	map.bridges = [Vector2i(14, 15)]
	map.bridge_style = "arch"
	map.backdrop = "mountains"
	map.backdrop_height = 650.0
	map.sun_elevation = 38.0
	return map


static func tokyo() -> MapDef:
	var map := MapDef.new()
	map.id = "tokyo"
	map.display_name = "Tokyo by Night"
	map.description = "Neon-lit streets, the Sumida river, Tokyo Tower and Mount Fuji on the horizon."
	map.fare = 20
	map.scenery_seed = 41
	map.points = _pts(
		[
			[0, 0],
			[250, 0],
			[320, 40],
			[340, 130],
			[340, 300],
			[370, 360],
			[420, 395],
			[560, 400],
			[650, 400],
			[790, 410],
			[840, 450],
			[860, 530],
			[855, 690],
			[825, 765],
			[760, 800],
			[650, 800],
			[560, 800],
			[420, 800],
			[360, 805],
			[300, 830],
			[220, 900],
			[100, 900],
			[-20, 860],
			[-80, 760],
			[-80, 500],
			[-40, 420],
			[-60, 300],
			[-90, 180],
			[-60, 60],
		]
	)
	map.heights = PackedFloat32Array(
		[0, 0, 0, 0, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	)
	map.stops = [0.02, 0.209, 0.4, 0.59, 0.78, 0.97]
	map.stop_names = PackedStringArray(
		[
			"Shibuya",
			"Harajuku",
			"Asakusa",
			"Akihabara",
			"Shinjuku",
			"Shibuya Terminal",
		]
	)
	map.traffic_cars = 18
	map.style = "tokyo"
	map.night = true
	map.ground_color = Color(0.45, 0.45, 0.47)
	map.sky_top = Color(0.02, 0.03, 0.09)
	map.sky_horizon = Color(0.14, 0.12, 0.25)
	map.cloud_cover = 0.3
	map.building_colors = [
		Color(0.62, 0.62, 0.66),
		Color(0.75, 0.73, 0.7),
		Color(0.5, 0.52, 0.58),
		Color(0.85, 0.82, 0.78)
	]
	map.floors = Vector2i(5, 16)
	map.block_length = Vector2(45, 70)
	map.tree_chance = 0.05
	map.rivers = [{"points": _pts([[605, -700], [610, 600], [600, 1600]]), "width": 60.0}]
	map.bridges = [Vector2i(7, 8), Vector2i(15, 16)]
	map.bridge_style = "suspension"
	map.landmarks = [{"type": "tokyo_tower", "at": Vector2(150, 450), "rotation": 0.0}]
	map.backdrop = "fuji"
	map.backdrop_height = 380.0
	map.sun_elevation = 25.0
	return map


static func new_york() -> MapDef:
	var map := MapDef.new()
	map.id = "new_york"
	map.display_name = "New York City"
	map.description = "Manhattan canyons, Central Park and two crossings of the East River."
	map.fare = 22
	map.scenery_seed = 59
	map.points = _pts(
		[
			[0, 0],
			[250, 0],
			[330, 30],
			[400, 30],
			[540, 30],
			[640, 30],
			[780, 30],
			[840, 80],
			[860, 170],
			[860, 470],
			[830, 560],
			[780, 590],
			[640, 590],
			[540, 590],
			[400, 590],
			[330, 620],
			[300, 700],
			[300, 1000],
			[270, 1060],
			[200, 1080],
			[0, 1080],
			[-70, 1050],
			[-90, 980],
			[-90, 100],
			[-60, 30],
		]
	)
	map.heights = PackedFloat32Array(
		[0, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	)
	map.stops = [0.02, 0.218, 0.364, 0.59, 0.78, 0.97]
	map.stop_names = PackedStringArray(
		[
			"Penn Station",
			"Brooklyn Heights",
			"DUMBO",
			"Times Square",
			"Central Park",
			"Penn Station Terminal",
		]
	)
	map.traffic_cars = 22
	map.style = "nyc"
	map.ground_color = Color(0.58, 0.57, 0.55)
	map.sky_top = Color(0.35, 0.52, 0.8)
	map.sky_horizon = Color(0.8, 0.82, 0.85)
	map.cloud_cover = 0.5
	map.building_colors = [
		Color(0.62, 0.48, 0.4),
		Color(0.72, 0.7, 0.66),
		Color(0.5, 0.5, 0.52),
		Color(0.8, 0.76, 0.68)
	]
	map.floors = Vector2i(8, 30)
	map.block_length = Vector2(60, 80)
	map.tree_chance = 0.04
	map.rivers = [{"points": _pts([[590, -700], [592, 500], [588, 1800]]), "width": 70.0}]
	map.bridges = [Vector2i(4, 5), Vector2i(12, 13)]
	map.bridge_style = "suspension"
	map.landmarks = [{"type": "empire", "at": Vector2(110, 300), "rotation": 0.0}]
	map.parks = [Rect2(20, 620, 220, 380)]
	map.backdrop = "skyline"
	map.backdrop_height = 160.0
	map.sun_elevation = 45.0
	return map
