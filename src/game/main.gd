extends Node
## Entry point: switches between the menu and a driving session.

var menu: MainMenu
var session: DriveSession


func _ready() -> void:
	InputSetup.ensure_actions()
	show_menu()


func show_menu() -> void:
	_clear_session()
	menu = MainMenu.new()
	menu.drive_requested.connect(start_drive)
	add_child(menu)


func start_drive() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
		menu = null
	session = DriveSession.create(Maps.harbor(), BusSpec.new())
	session.exit_requested.connect(show_menu)
	add_child(session)


func _clear_session() -> void:
	if is_instance_valid(session):
		session.queue_free()
		session = null
