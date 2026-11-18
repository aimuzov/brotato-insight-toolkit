extends "res://ui/menus/shop/coop_shop_player_container.gd"

const DC_DIR = "res://mods-unpacked/aimuzov-InsightToolkit/"

var _dc_creeps
var _dc_heading
var _dc_page


func _ready() -> void:
	_dc_heading = carousel._headings.get_child(2).duplicate()
	_dc_heading.text = "Крипы"
	_dc_heading.hide()
	_dc_page = CenterContainer.new()
	_dc_page.hide()
	_dc_page.anchor_right = 1.0
	var panel = PanelContainer.new()
	panel.rect_min_size = Vector2(400, 700)
	panel.add_stylebox_override("panel", primary_stats_container.get_stylebox("panel"))
	_dc_creeps = load(DC_DIR + "ui/creep_stats.gd").new()
	_dc_creeps.player_index = player_index
	panel.add_child(_dc_creeps)
	_dc_page.add_child(panel)
	carousel.connect("index_changed", self, "_dc_on_page_changed")
	add_to_group("dc_creep_stats")
	add_to_group("dc_short_names")
	_dc_refresh_short_names()
	_dc_sync_creep_setting()


func _dc_refresh_short_names() -> void:
	var translations = load(DC_DIR + "core/translations.gd")
	carousel._headings.get_child(1).text = translations.text("PRIMARY")
	carousel._headings.get_child(2).text = translations.text("SECONDARY")


func _dc_sync_creep_setting() -> void:
	var enabled = load(DC_DIR + "core/settings.gd").enabled("creep_stats")
	var mounted = _dc_page.get_parent() != null
	if enabled == mounted:
		return
	var index = carousel.index
	if enabled:
		carousel._headings.add_child(_dc_heading)
		carousel._headings.move_child(_dc_heading, 3)
		carousel._content.add_child(_dc_page)
		carousel._content.move_child(_dc_page, 3)
		if index >= 3:
			index += 1
	else:
		carousel._headings.remove_child(_dc_heading)
		carousel._content.remove_child(_dc_page)
		if index >= 3:
			index -= 1
	carousel.index = index
	carousel.emit_signal("index_changed", carousel.index)


func _exit_tree() -> void:
	if is_instance_valid(_dc_page) and _dc_page.get_parent() == null:
		_dc_page.free()
	if is_instance_valid(_dc_heading) and _dc_heading.get_parent() == null:
		_dc_heading.free()


func _dc_on_page_changed(_index: int) -> void:
	_dc_creeps.player_index = player_index
	_dc_creeps.refresh()
