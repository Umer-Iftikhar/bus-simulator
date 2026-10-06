extends Node
## Entry point. Owns the save game and switches between the main menu, the
## garage and driving sessions. Progress is saved after every change.

## Where progress is stored (tests point this somewhere disposable).
var save_path := SaveService.DEFAULT_PATH
## Passenger seed for runs; -1 picks a random one each run.
var run_seed := -1
var service: SaveService
var save: SaveData
var garage: Garage
var menu: MainMenu
var garage_menu: GarageMenu
var session: DriveSession


func _ready() -> void:
	InputSetup.ensure_actions()
	service = SaveService.new(save_path)
	save = service.load_or_new()
	garage = Garage.new(save)
	show_menu()


func persist() -> void:
	var error := service.save(save)
	if error != OK:
		push_warning("Could not save progress: %s" % error_string(error))


func show_menu() -> void:
	_store_session_damage()
	_clear_screens()
	menu = MainMenu.create(save, garage)
	menu.drive_requested.connect(start_drive)
	menu.garage_requested.connect(show_garage)
	menu.selection_changed.connect(persist)
	add_child(menu)


func show_garage() -> void:
	_clear_screens()
	garage_menu = GarageMenu.create(save, garage)
	garage_menu.purchased.connect(persist)
	garage_menu.back_requested.connect(show_menu)
	add_child(garage_menu)


func start_drive() -> void:
	_clear_screens()
	var map := Maps.get_map(save.selected_map)
	if garage.damage_of(save.selected_bus).is_wrecked():
		show_menu()
		return
	var options := {
		"performance": garage.performance(save.selected_bus),
		"damage": save.damage(save.selected_bus),
		"graphics": save.graphics(),
		"cosmetics": save.cosmetics(save.selected_bus),
	}
	if run_seed >= 0:
		options["seed"] = run_seed
	session = DriveSession.create(map, garage.spec_for(save.selected_bus), options)
	session.run_finished.connect(_on_run_finished)
	session.exit_requested.connect(show_menu)
	add_child(session)


func _on_run_finished(result: Dictionary) -> void:
	garage.record_run(result["payout"], result["delivered"])
	_store_session_damage()
	persist()


## Damage sticks to the bus whether the run was finished, failed or abandoned.
func _store_session_damage() -> void:
	if is_instance_valid(session) and session.damage != null:
		garage.store_damage(save.selected_bus, session.damage)
		persist()


func _clear_screens() -> void:
	for screen in [menu, garage_menu, session]:
		if is_instance_valid(screen):
			screen.queue_free()
	menu = null
	garage_menu = null
	session = null
