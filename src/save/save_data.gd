class_name SaveData
extends RefCounted
## Everything that persists between sessions. Serialised to JSON by [SaveService].
##
## Loading is defensive: unknown buses and paints are dropped, levels are
## clamped and the starter bus is always owned, so a hand-edited or
## partially-corrupt save can never break the game.

const VERSION := 1

var wallet := Wallet.new()
## bus_id -> {"upgrades": {key: level}, "paint": id, "paints": [ids], "damage": {}}
var owned := {}
var selected_bus := Catalog.STARTER_BUS
var selected_map := "harbor"
var stats := {"runs": 0, "delivered": 0, "earned": 0}
var settings := {"graphics": GraphicsSettings.DEFAULT}
var money: int:
	get:
		return wallet.balance


static func new_game() -> SaveData:
	var data := SaveData.new()
	data.owned[Catalog.STARTER_BUS] = default_owned_bus()
	return data


static func default_owned_bus() -> Dictionary:
	var upgrades := {}
	for kind in Catalog.UPGRADE_KEYS:
		upgrades[Catalog.upgrade_key(kind)] = 0
	return {"upgrades": upgrades, "paint": "stock", "paints": ["stock"], "damage": {}}


func graphics() -> String:
	return settings["graphics"]


func owns(bus_id: String) -> bool:
	return owned.has(bus_id)


func owned_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for bus_id in Catalog.bus_ids():
		if owned.has(bus_id):
			ids.append(bus_id)
	return ids


func upgrade_level(bus_id: String, kind: Catalog.Upgrade) -> int:
	if not owns(bus_id):
		return 0
	return owned[bus_id]["upgrades"].get(Catalog.upgrade_key(kind), 0)


func paint(bus_id: String) -> String:
	return owned[bus_id]["paint"] if owns(bus_id) else "stock"


func damage(bus_id: String) -> Dictionary:
	return owned[bus_id]["damage"] if owns(bus_id) else {}


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"money": wallet.balance,
		"owned": owned.duplicate(true),
		"selected_bus": selected_bus,
		"selected_map": selected_map,
		"stats": stats.duplicate(),
		"settings": settings.duplicate(),
	}


static func from_dict(data: Dictionary) -> SaveData:
	var save := SaveData.new()
	save.wallet = Wallet.new(maxi(int(data.get("money", 0)), 0))
	var raw_owned = data.get("owned", {})
	if raw_owned is Dictionary:
		for bus_id in raw_owned:
			if Catalog.has_bus(str(bus_id)) and raw_owned[bus_id] is Dictionary:
				save.owned[str(bus_id)] = _sanitize_owned(raw_owned[bus_id])
	if not save.owned.has(Catalog.STARTER_BUS):
		save.owned[Catalog.STARTER_BUS] = default_owned_bus()
	var bus := str(data.get("selected_bus", Catalog.STARTER_BUS))
	save.selected_bus = bus if save.owned.has(bus) else Catalog.STARTER_BUS
	var map := str(data.get("selected_map", "harbor"))
	save.selected_map = map if Maps.get_map(map) != null else Maps.ids()[0]
	var raw_settings = data.get("settings", {})
	if raw_settings is Dictionary:
		var preset := str(raw_settings.get("graphics", ""))
		if preset.is_empty() and raw_settings.get("mirror_quality", "") == "low":
			preset = "low"  # Older saves only had a battery-saver mirror option.
		save.settings["graphics"] = (
			preset if GraphicsSettings.is_valid(preset) else GraphicsSettings.DEFAULT
		)
	var raw_stats = data.get("stats", {})
	if raw_stats is Dictionary:
		for key in save.stats:
			save.stats[key] = maxi(int(raw_stats.get(key, 0)), 0)
	return save


static func _sanitize_owned(raw: Dictionary) -> Dictionary:
	var clean := default_owned_bus()
	var upgrades = raw.get("upgrades", {})
	if upgrades is Dictionary:
		for key in clean["upgrades"]:
			clean["upgrades"][key] = clampi(int(upgrades.get(key, 0)), 0, Catalog.MAX_UPGRADE_LEVEL)
	var paints = raw.get("paints", [])
	if paints is Array:
		for paint_id in paints:
			if Catalog.paint_ids().has(str(paint_id)) and not clean["paints"].has(str(paint_id)):
				clean["paints"].append(str(paint_id))
	var paint_id := str(raw.get("paint", "stock"))
	clean["paint"] = paint_id if clean["paints"].has(paint_id) else "stock"
	var raw_damage = raw.get("damage", {})
	if raw_damage is Dictionary:
		for part in raw_damage:
			clean["damage"][str(part)] = clampf(float(raw_damage[part]), 0.0, 1.0)
	return clean
