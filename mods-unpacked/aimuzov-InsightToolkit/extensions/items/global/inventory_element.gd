extends "res://items/global/inventory_element.gd"

const SEEN_META = "dc_tumor_seen_effects"
const Style = preload("res://mods-unpacked/aimuzov-InsightToolkit/ui/style.gd")

var _dc_unread_frame: Panel


func set_element(item_data: Resource) -> void:
	.set_element(item_data)
	if item is ItemParentData and item.my_id == "item_tumor":
		_recently_mutated.hide()
		if not is_in_group("dc_tumor_inventory"):
			add_to_group("dc_tumor_inventory")
	elif is_in_group("dc_tumor_inventory"):
		remove_from_group("dc_tumor_inventory")
	_dc_sync_tumor_unread()


func _dc_tumor_owner():
	if not is_in_group("dc_tumor_inventory"):
		return null
	if player_index >= 0 and player_index < RunData.get_player_count() and RunData.get_player_items(player_index).has(item):
		return RunData.players_data[player_index]
	for index in RunData.get_player_count():
		if RunData.get_player_items(index).has(item):
			return RunData.players_data[index]
	return null


func _dc_tumor_signature() -> String:
	var effects = []
	for effect in item.effects:
		effects.push_back(effect.serialize())
	return JSON.print(effects, "", true)


func _dc_sync_tumor_unread() -> void:
	var player = _dc_tumor_owner()
	var unread = false
	if player != null and not item.effects.empty():
		var seen = player.get_meta(SEEN_META) if player.has_meta(SEEN_META) else ""
		# Старые версии сохраняли массив словарей. Сравниваем содержимое эффектов.
		if seen is Array:
			seen = JSON.print(seen, "", true)
		unread = seen != _dc_tumor_signature()
	if unread and _dc_unread_frame == null:
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
		_dc_unread_frame.visible = unread


func _dc_tumor_viewed() -> void:
	var player = _dc_tumor_owner()
	if player == null:
		return
	player.set_meta(SEEN_META, _dc_tumor_signature())
	player.recently_mutated.erase(item)
	get_tree().call_group_flags(SceneTree.GROUP_CALL_REALTIME, "dc_tumor_inventory", "_dc_sync_tumor_unread")
