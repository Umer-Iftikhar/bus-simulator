class_name Garage
extends RefCounted
## Purchase rules on top of [SaveData]: buying buses, upgrades and paint,
## selecting what to drive, and banking run earnings.

enum Result { OK, ALREADY_OWNED, NOT_OWNED, UNKNOWN_ITEM, CANT_AFFORD, MAXED, NOT_DAMAGED }

const RESULT_TEXT := {
	Result.OK: "Done",
	Result.ALREADY_OWNED: "Already owned",
	Result.NOT_OWNED: "You don't own that bus",
	Result.UNKNOWN_ITEM: "Unknown item",
	Result.CANT_AFFORD: "Not enough money",
	Result.MAXED: "Already at max level",
	Result.NOT_DAMAGED: "Nothing to repair",
}

var save: SaveData


func _init(save_data: SaveData) -> void:
	save = save_data


func buy_bus(bus_id: String) -> Result:
	if not Catalog.has_bus(bus_id):
		return Result.UNKNOWN_ITEM
	if save.owns(bus_id):
		return Result.ALREADY_OWNED
	if not save.wallet.spend(Catalog.bus_price(bus_id)):
		return Result.CANT_AFFORD
	save.owned[bus_id] = SaveData.default_owned_bus()
	return Result.OK


func select_bus(bus_id: String) -> Result:
	if not save.owns(bus_id):
		return Result.NOT_OWNED
	save.selected_bus = bus_id
	return Result.OK


func select_map(map_id: String) -> Result:
	if Maps.get_map(map_id) == null:
		return Result.UNKNOWN_ITEM
	save.selected_map = map_id
	return Result.OK


func next_upgrade_price(bus_id: String, kind: Catalog.Upgrade) -> int:
	return Catalog.upgrade_price(kind, save.upgrade_level(bus_id, kind), bus_id)


func buy_upgrade(bus_id: String, kind: Catalog.Upgrade) -> Result:
	if not save.owns(bus_id):
		return Result.NOT_OWNED
	var price := next_upgrade_price(bus_id, kind)
	if price < 0:
		return Result.MAXED
	if not save.wallet.spend(price):
		return Result.CANT_AFFORD
	save.owned[bus_id]["upgrades"][Catalog.upgrade_key(kind)] += 1
	return Result.OK


## Buys (or, if already bought for this bus, re-applies for free) a paint job.
func buy_paint(bus_id: String, paint_id: String) -> Result:
	if not save.owns(bus_id):
		return Result.NOT_OWNED
	var entry := Catalog.paint_entry(paint_id)
	if entry.is_empty():
		return Result.UNKNOWN_ITEM
	var bus: Dictionary = save.owned[bus_id]
	if not bus["paints"].has(paint_id):
		if not save.wallet.spend(entry["price"]):
			return Result.CANT_AFFORD
		bus["paints"].append(paint_id)
	bus["paint"] = paint_id
	return Result.OK


func damage_of(bus_id: String) -> DamageModel:
	return DamageModel.from_dict(save.damage(bus_id))


func repair_cost(bus_id: String) -> int:
	return damage_of(bus_id).repair_cost(bus_id)


## Repairing is optional: a dented bus still drives (slower) until it's wrecked.
func repair(bus_id: String) -> Result:
	if not save.owns(bus_id):
		return Result.NOT_OWNED
	var model := damage_of(bus_id)
	if model.is_pristine():
		return Result.NOT_DAMAGED
	if not save.wallet.spend(model.repair_cost(bus_id)):
		return Result.CANT_AFFORD
	save.owned[bus_id]["damage"] = {}
	return Result.OK


func store_damage(bus_id: String, model: DamageModel) -> void:
	if save.owns(bus_id):
		save.owned[bus_id]["damage"] = model.to_dict()


## Performance multipliers from upgrades: keys match [constant Catalog.UPGRADE_KEYS].
func performance(bus_id: String) -> Dictionary:
	var factors := {}
	for kind in Catalog.UPGRADE_KEYS:
		var level := save.upgrade_level(bus_id, kind)
		factors[Catalog.upgrade_key(kind)] = Catalog.upgrade_factor(kind, level)
	return factors


## Stock spec of [param bus_id] wearing its current paint.
func spec_for(bus_id: String) -> BusSpec:
	var spec := Catalog.bus_spec(bus_id)
	spec.color = Catalog.paint_color(bus_id, save.paint(bus_id))
	return spec


## Banks a finished run: pays out and updates lifetime stats.
func record_run(payout: int, delivered: int) -> void:
	save.wallet.earn(payout)
	save.stats["runs"] += 1
	save.stats["delivered"] += delivered
	save.stats["earned"] += maxi(payout, 0)
