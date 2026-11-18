extends "res://items/global/inventory_element.gd"

const SEEN_META = "dc_tumor_seen_effects"
const Style = preload("res://mods-unpacked/aimuzov-DpsCheck/ui/style.gd")

var _dc_effects = []
var _dc_unread = false
var _dc_unread_frame: Panel


func set_element(item_data: Resource) -> void:
	.set_element(item_data)
	_dc_effects.clear()
	if item_data is ItemParentData and item_data.my_id == "item_tumor":
		if player_index >= 0 and player_index < RunData.get_player_count() and RunData.get_player_items(player_index).has(item_data):
			for effect in item_data.effects:
				_dc_effects.push_back(effect.serialize())
			add_to_group("dc_tumor_inventory")
	_dc_sync_tumor_unread()


func _dc_sync_tumor_unread() -> void:
	_dc_unread = false
	if not _dc_effects.empty() and player_index >= 0 and player_index < RunData.get_player_count():
		var player_data = RunData.players_data[player_index]
		if RunData.get_player_items(player_index).has(item):
			_dc_unread = not player_data.has_meta(SEEN_META) or player_data.get_meta(SEEN_META) != _dc_effects
	if _dc_unread and _dc_unread_frame == null:
		var border = StyleBoxFlat.new()
		border.bg_color = Color(Style.BEST.r, Style.BEST.g, Style.BEST.b, 0.08)
		border.border_color = Style.BEST
		border.set_border_width_all(2)
		border.set_corner_radius_all(8)
		_dc_unread_frame = Panel.new()
		_dc_unread_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dc_unread_frame.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		_dc_unread_frame.add_stylebox_override("panel", border)
		add_child(_dc_unread_frame)
	if _dc_unread_frame != null:
		_dc_unread_frame.visible = _dc_unread
	if item is ItemParentData and item.my_id == "item_tumor":
		_recently_mutated.visible = _dc_unread


func _mark_mutation_seen() -> void:
	._mark_mutation_seen()
	if not _dc_unread:
		return
	RunData.players_data[player_index].set_meta(SEEN_META, _dc_effects.duplicate(true))
	get_tree().call_group("dc_tumor_inventory", "_dc_sync_tumor_unread")
