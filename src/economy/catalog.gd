class_name Catalog
extends RefCounted
## Everything the player can buy: buses, performance upgrades and paint jobs.
##
## Capacity only comes from buying a bigger bus; upgrades never add seats.

enum Upgrade { TOP_SPEED, ACCELERATION, BRAKES, HANDLING }

const STARTER_BUS := "minibus"
const MAX_UPGRADE_LEVEL := 5
const UPGRADE_KEYS := {
	Upgrade.TOP_SPEED: "top_speed",
	Upgrade.ACCELERATION: "acceleration",
	Upgrade.BRAKES: "brakes",
	Upgrade.HANDLING: "handling",
}
const UPGRADE_NAMES := {
	Upgrade.TOP_SPEED: "Top speed",
	Upgrade.ACCELERATION: "Acceleration",
	Upgrade.BRAKES: "Brakes",
	Upgrade.HANDLING: "Handling",
}
## Multiplier gained per level.
const UPGRADE_STEP := {
	Upgrade.TOP_SPEED: 0.06,
	Upgrade.ACCELERATION: 0.10,
	Upgrade.BRAKES: 0.10,
	Upgrade.HANDLING: 0.12,
}
const UPGRADE_BASE_PRICE := {
	Upgrade.TOP_SPEED: 250,
	Upgrade.ACCELERATION: 200,
	Upgrade.BRAKES: 150,
	Upgrade.HANDLING: 150,
}
const UPGRADE_PRICE_GROWTH := 1.6

const BUSES := [
	{
		"id": "minibus",
		"style": "minibus",
		"display_name": "Minibus",
		"price": 0,
		"capacity": 12,
		"mass": 3500.0,
		"engine_force": 9000.0,
		"brake_force": 60.0,
		"max_steer": 0.55,
		"top_speed": 19.0,
		"length": 7.0,
		"width": 2.3,
		"height": 2.8,
		"color": Color(0.95, 0.75, 0.2),
	},
	{
		"id": "city",
		"style": "city",
		"display_name": "City Bus",
		"price": 3000,
		"capacity": 32,
		"mass": 9000.0,
		"engine_force": 21000.0,
		"brake_force": 155.0,
		"max_steer": 0.52,
		"top_speed": 20.0,
		"length": 11.0,
		"width": 2.5,
		"height": 3.1,
		"color": Color(0.2, 0.45, 0.85),
	},
	{
		"id": "long_city",
		"style": "city",
		"display_name": "Long City Bus",
		"price": 12000,
		"capacity": 48,
		"mass": 12500.0,
		"engine_force": 28000.0,
		"brake_force": 210.0,
		"max_steer": 0.5,
		"top_speed": 19.5,
		"length": 13.5,
		"width": 2.55,
		"height": 3.1,
		"color": Color(0.85, 0.2, 0.2),
	},
	{
		"id": "coach",
		"style": "coach",
		"display_name": "Express Coach",
		"price": 30000,
		"capacity": 55,
		"mass": 13500.0,
		"engine_force": 38000.0,
		"brake_force": 230.0,
		"max_steer": 0.48,
		"top_speed": 26.0,
		"length": 12.5,
		"width": 2.55,
		"height": 3.5,
		"color": Color(0.92, 0.92, 0.95),
	},
	{
		"id": "double_decker",
		"style": "double_decker",
		"display_name": "Double Decker",
		"price": 55000,
		"capacity": 80,
		"mass": 13000.0,
		"engine_force": 30000.0,
		"brake_force": 220.0,
		"max_steer": 0.52,
		"top_speed": 18.0,
		"length": 11.2,
		"width": 2.55,
		"height": 4.3,
		"color": Color(0.7, 0.1, 0.15),
	},
]

const PAINTS := [
	{"id": "stock", "display_name": "Factory", "price": 0, "color": Color(0, 0, 0, 0)},
	{"id": "sunflower", "display_name": "Sunflower", "price": 300, "color": Color(1.0, 0.8, 0.1)},
	{"id": "ocean", "display_name": "Ocean", "price": 300, "color": Color(0.1, 0.45, 0.75)},
	{"id": "forest", "display_name": "Forest", "price": 300, "color": Color(0.15, 0.45, 0.25)},
	{"id": "cherry", "display_name": "Cherry", "price": 450, "color": Color(0.75, 0.05, 0.15)},
	{"id": "midnight", "display_name": "Midnight", "price": 600, "color": Color(0.08, 0.08, 0.18)},
	{"id": "gold", "display_name": "Gold Rush", "price": 2500, "color": Color(0.85, 0.65, 0.2)},
	{"id": "lime", "display_name": "Lime", "price": 350, "color": Color(0.5, 0.8, 0.15)},
	{"id": "tangerine", "display_name": "Tangerine", "price": 350, "color": Color(0.95, 0.45, 0.1)},
	{"id": "silver", "display_name": "Silver", "price": 800, "color": Color(0.72, 0.74, 0.76)},
	{"id": "pearl", "display_name": "Pearl White", "price": 900, "color": Color(0.95, 0.94, 0.9)},
]
const STRIPES := [
	{"id": "none", "display_name": "None", "price": 0},
	{"id": "white", "display_name": "White", "price": 300, "color": Color(0.95, 0.95, 0.95)},
	{"id": "black", "display_name": "Black", "price": 300, "color": Color(0.05, 0.05, 0.06)},
	{"id": "red", "display_name": "Racing Red", "price": 400, "color": Color(0.8, 0.05, 0.05)},
	{"id": "blue", "display_name": "Blue", "price": 400, "color": Color(0.1, 0.3, 0.8)},
	{"id": "gold", "display_name": "Gold", "price": 900, "color": Color(0.85, 0.65, 0.2)},
]
const RIMS := [
	{
		"id": "steel",
		"display_name": "Steel",
		"price": 0,
		"color": Color(0.75, 0.76, 0.78),
		"metallic": 0.8,
		"roughness": 0.3,
	},
	{
		"id": "chrome",
		"display_name": "Chrome",
		"price": 500,
		"color": Color(0.95, 0.95, 0.97),
		"metallic": 1.0,
		"roughness": 0.05,
	},
	{
		"id": "black",
		"display_name": "Matte Black",
		"price": 400,
		"color": Color(0.06, 0.06, 0.07),
		"metallic": 0.4,
		"roughness": 0.7,
	},
	{
		"id": "gold",
		"display_name": "Gold",
		"price": 1800,
		"color": Color(0.9, 0.7, 0.25),
		"metallic": 1.0,
		"roughness": 0.15,
	},
]
const TINTS := [
	{"id": "clear", "display_name": "Clear", "price": 0, "darkness": 0.0},
	{"id": "smoke", "display_name": "Smoke", "price": 300, "darkness": 0.45},
	{"id": "dark", "display_name": "Limo Dark", "price": 500, "darkness": 0.85},
]
const ROOFS := [
	{"id": "body", "display_name": "Body colour", "price": 0},
	{"id": "white", "display_name": "White", "price": 200, "color": Color(0.95, 0.95, 0.95)},
	{"id": "black", "display_name": "Black", "price": 250, "color": Color(0.07, 0.07, 0.08)},
]
## Every cosmetic category; the first item in each list is the free default.
const COSMETICS := {
	"paint": PAINTS,
	"stripe": STRIPES,
	"rims": RIMS,
	"tint": TINTS,
	"roof": ROOFS,
}
const COSMETIC_NAMES := {
	"paint": "Paint",
	"stripe": "Livery stripe",
	"rims": "Rims",
	"tint": "Window tint",
	"roof": "Roof",
}


static func cosmetic_categories() -> PackedStringArray:
	return PackedStringArray(COSMETICS.keys())


static func cosmetic_ids(category: String) -> PackedStringArray:
	var ids := PackedStringArray()
	for item in COSMETICS.get(category, []):
		ids.append(item["id"])
	return ids


static func cosmetic_default(category: String) -> String:
	return COSMETICS[category][0]["id"]


static func cosmetic_entry(category: String, item_id: String) -> Dictionary:
	for item in COSMETICS.get(category, []):
		if item["id"] == item_id:
			return item
	return {}


static func bus_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for bus in BUSES:
		ids.append(bus["id"])
	return ids


static func has_bus(bus_id: String) -> bool:
	return bus_ids().has(bus_id)


static func bus_entry(bus_id: String) -> Dictionary:
	for bus in BUSES:
		if bus["id"] == bus_id:
			return bus
	return {}


static func bus_price(bus_id: String) -> int:
	return bus_entry(bus_id).get("price", 0)


## Stock spec for [param bus_id] (a fresh copy every call).
static func bus_spec(bus_id: String) -> BusSpec:
	return BusSpec.from_dict(bus_entry(bus_id))


static func upgrade_key(kind: Upgrade) -> String:
	return UPGRADE_KEYS[kind]


static func upgrade_from_key(key: String) -> int:
	for kind in UPGRADE_KEYS:
		if UPGRADE_KEYS[kind] == key:
			return kind
	return -1


## Price of raising [param kind] from [param current_level] to the next level.
## Pricier buses have pricier parts. Returns -1 when already maxed.
static func upgrade_price(kind: Upgrade, current_level: int, bus_id: String) -> int:
	if current_level >= MAX_UPGRADE_LEVEL:
		return -1
	var tier := 1.0 + bus_price(bus_id) / 20000.0
	var price: float = UPGRADE_BASE_PRICE[kind] * pow(UPGRADE_PRICE_GROWTH, current_level) * tier
	return int(round(price / 10.0)) * 10


static func upgrade_factor(kind: Upgrade, level: int) -> float:
	return 1.0 + UPGRADE_STEP[kind] * clampi(level, 0, MAX_UPGRADE_LEVEL)


static func paint_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for paint in PAINTS:
		ids.append(paint["id"])
	return ids


static func paint_entry(paint_id: String) -> Dictionary:
	for paint in PAINTS:
		if paint["id"] == paint_id:
			return paint
	return {}


## Body colour for a bus wearing [param paint_id] ("stock" keeps the factory colour).
static func paint_color(bus_id: String, paint_id: String) -> Color:
	if paint_id == "stock" or paint_entry(paint_id).is_empty():
		return bus_entry(bus_id).get("color", Color.WHITE)
	return paint_entry(paint_id)["color"]
