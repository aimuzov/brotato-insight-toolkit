extends "res://ui/menus/shop/stats_container.gd"

const DC_DIR = "res://mods-unpacked/aimuzov-DpsCheck/"

var _dc_creeps
var _dc_creep_tab


func _ready() -> void:
	if not show_buttons:
		return
	_dc_creeps = load(DC_DIR + "ui/creep_stats.gd").new()
	_dc_creeps.hide()
	_general_stats.get_parent().add_child(_dc_creeps)
	_dc_creep_tab = _secondary_tab.duplicate()
	for connection in _dc_creep_tab.get_signal_connection_list("pressed"):
		_dc_creep_tab.disconnect("pressed", connection.target, connection.method)
	_dc_creep_tab.text = "Крипы"
	_dc_creep_tab.name = "DpsCheckCreeps"
	_dc_creep_tab.connect("pressed", self, "_dc_show_creeps")
	_buttons_container.add_child(_dc_creep_tab)
	_buttons_container.move_child(_dc_creep_tab, 2)
	for button in [_primary_tab, _secondary_tab, _dc_creep_tab]:
		button.rect_min_size.x = 0
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.add_font_override("font", load(DC_DIR + "ui/style.gd").font(20))
	set_focus_neighbours()
	add_to_group("dc_creep_stats")
	add_to_group("dc_short_names")
	_dc_refresh_short_names()
	_dc_sync_creep_setting()


func _dc_refresh_short_names() -> void:
	var translations = load(DC_DIR + "core/translations.gd")
	_primary_tab.text = translations.text("PRIMARY")
	_secondary_tab.text = translations.text("SECONDARY")


func _dc_sync_creep_setting() -> void:
	var enabled = load(DC_DIR + "core/settings.gd").enabled("creep_stats")
	if not enabled and focused_tab == 2:
		update_tab(Tab.PRIMARY)
		_primary_tab.grab_focus()
	_dc_creep_tab.visible = enabled
	set_focus_neighbours()


func _input(event: InputEvent) -> void:
	if _dc_creeps != null and event is InputEventJoypadButton:
		var direction = int(event.is_action_pressed("rtrigger")) - int(event.is_action_pressed("ltrigger"))
		if direction != 0:
			var tab_count = 3 if _dc_creep_tab.visible else 2
			update_tab(posmod(focused_tab + direction, tab_count))
			return
	._input(event)


func update_tab(tab: int) -> void:
	if tab == 2 and _dc_creeps != null:
		_dc_show_creeps()
	else:
		.update_tab(tab)
		if _dc_creeps != null:
			_dc_hide_creeps()


func update_player_stats(player_index: int) -> void:
	.update_player_stats(player_index)
	if _dc_creeps != null:
		_dc_creeps.player_index = player_index
		_dc_creeps.refresh()


func _dc_show_creeps() -> void:
	focused_tab = 2
	var focused = get_focus_owner()
	if focused != null and (_primary_stats.is_a_parent_of(focused) or _secondary_stats.is_a_parent_of(focused)):
		_dc_creep_tab.grab_focus()
	_general_stats.hide()
	_primary_stats.hide()
	_secondary_stats.hide()
	_set_flat(_primary_tab, false)
	_set_flat(_secondary_tab, false)
	_set_flat(_dc_creep_tab, true)
	_dc_creeps.refresh()
	_dc_creeps.show()
	set_focus_neighbours()


func _dc_hide_creeps() -> void:
	_dc_creeps.hide()
	_set_flat(_dc_creep_tab, false)


func set_focus_neighbours() -> void:
	.set_focus_neighbours()
	if _dc_creep_tab == null or not _dc_creep_tab.visible:
		return
	_secondary_tab.focus_neighbour_right = _secondary_tab.get_path_to(_dc_creep_tab)
	_dc_creep_tab.focus_neighbour_left = _dc_creep_tab.get_path_to(_secondary_tab)
	_dc_creep_tab.focus_neighbour_top = _secondary_tab.focus_neighbour_top
	_dc_creep_tab.focus_neighbour_right = _dc_creep_tab.get_path_to(get_node(focus_neighbour_right)) if focus_neighbour_right else NodePath("")
