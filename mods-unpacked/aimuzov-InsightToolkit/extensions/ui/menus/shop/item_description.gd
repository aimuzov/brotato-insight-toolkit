extends "res://ui/menus/shop/item_description.gd"

const REWARD_PANEL_WIDTH = 455

var _dc_item_count = 1
var _dc_description_version = 0


func _ready() -> void:
	add_to_group("dc_short_names")


func set_item(item_data: ItemParentData, player_index: int, item_count: = 1) -> void:
	_dc_description_version += 1
	set_meta("dc_description_version", _dc_description_version)
	_dc_item_count = item_count
	.set_item(item_data, player_index, item_count)
	# Высоту шапки задают все строки названия вместе с категорией.
	var header_scroll = _name.get_parent().get_parent()
	if header_scroll is ScrollContainer:
		header_scroll.scroll_vertical_enabled = false
	var title_height = _name.get_font("font").get_height()
	var reward_panel = owner.get_node_or_null("%ItemPanelContainer") if owner != null else null
	if reward_panel != null and reward_panel.is_a_parent_of(self):
		if RunData.is_coop_run:
			reward_panel.size_flags_horizontal = Control.SIZE_FILL
		else:
			reward_panel.rect_min_size.x = REWARD_PANEL_WIDTH
		icon_panel.rect_min_size = Vector2(title_height, title_height)
		# Игра начинает текст счётчика с перевода строки перед тегом цвета.
		for line in get_effects().get_children():
			if line is EffectLine and line.effect == null and not line.is_queued_for_deletion():
				var text = line.text_descr.bbcode_text
				if text.begins_with("\n[color="):
					line.text_descr.bbcode_text = text.trim_prefix("\n")
		return
	var category_height = _category.get_combined_minimum_size().y
	var separation = _name.get_parent().get_constant("separation")
	var side = ceil(title_height + category_height + separation)
	icon_panel.rect_min_size = Vector2(side, side)


func _dc_refresh_short_names() -> void:
	if item != null:
		set_item(item, _player_index, _dc_item_count)


func _generate_description_effects(player_index, effects: Array, colored: bool = true, activate_tab: bool = true, removed_effects: Array = []):
	if item != null and item.my_id == "item_tumor":
		effects = effects.duplicate()
		effects.invert()
	._generate_description_effects(player_index, effects, colored, activate_tab, removed_effects)
	var show_totals = load("res://mods-unpacked/aimuzov-InsightToolkit/core/settings.gd").enabled("stat_totals")
	var upgrade = name == "UpgradeDescription"
	if not show_totals and not upgrade:
		return
	if item == null or item is CharacterData or item is DifficultyData:
		return
	if player_index < 0 or player_index >= RunData.get_player_count():
		return
	if RunData.get_player_character(player_index) == null:
		return
	var preview = load("res://mods-unpacked/aimuzov-InsightToolkit/core/stat_preview.gd")
	var owned = has_meta("dc_item_owned") and get_meta("dc_item_owned")
	var price = 0.0
	var ancestor = get_parent()
	while ancestor != null:
		if ancestor.has_method("get_dismantle_price") and ancestor.get("item_data") == item:
			price = float(ancestor.get("value"))
			break
		ancestor = ancestor.get_parent()
	var values = preview.totals(item, player_index, owned, price) if show_totals else {}
	for line in get_effects().get_children():
		if line is EffectLine and not line.is_queued_for_deletion() and line.effect != null and not removed_effects.has(line.effect):
			preview.format_line(line, player_index, values, colored, upgrade)
	preview.append_related(self, values, colored, upgrade, owner is ShopItem)
