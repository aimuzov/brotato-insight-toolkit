extends "res://ui/menus/shop/item_popup.gd"

const Settings = preload("res://mods-unpacked/aimuzov-InsightToolkit/core/settings.gd")
const CONTENT_MARGIN = 16
const HEADER_GAP = 8

var _dc_original_margins = {}
var _dc_original_style_margins = {}
var _dc_original_panel_width = 0.0
var _dc_original_description_separation = 0
var _dc_original_header_min_height = 0.0
var _dc_spacer: Control
var _dc_spacer_was_visible = false
var _dc_footer = []
var _dc_footer_spacer: Control
var _dc_owned = false
var _dc_advisor


func _ready() -> void:
	var margin = _panel._global_container
	var style = _panel.get_stylebox("panel")
	_dc_original_panel_width = _panel.rect_min_size.x
	_dc_original_description_separation = _panel._item_description.get_constant("separation")
	_dc_original_header_min_height = _panel._item_description.get_node("HBoxContainer").rect_min_size.y
	for side in ["left", "top", "right", "bottom"]:
		_dc_original_margins[side] = margin.get_constant("margin_" + side)
		_dc_original_style_margins[side] = style.get("content_margin_" + side)
	_dc_spacer = margin.get_node_or_null("VBoxContainer/EmptySpace")
	if _dc_spacer != null:
		_dc_spacer_was_visible = _dc_spacer.visible
	for control in [_combine_button, _upgrade_button, _discard_button, _effect_choice_container, _cancel_button]:
		if control != null:
			_dc_footer.push_back({"node": control, "flags": control.size_flags_horizontal, "width": control.rect_min_size.x})
	_dc_footer_spacer = Control.new()
	_dc_footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dc_footer_spacer.hide()
	var column = margin.get_node("VBoxContainer")
	column.add_child(_dc_footer_spacer)
	column.connect("resized", self, "_dc_sync_footer")
	add_to_group("dc_wide_tooltips")
	add_to_group("dc_item_advice")
	_dc_sync_popup_layout()


func _update_button_visibilities() -> void:
	._update_button_visibilities()
	_dc_sync_footer()
	_dc_refresh_advice()


func _dc_sync_footer() -> void:
	if _dc_footer_spacer == null:
		return
	var enabled = Settings.enabled("wide_tooltips")
	var column = _dc_footer_spacer.get_parent()
	var has_buttons = false
	for entry in _dc_footer:
		var control = entry.node
		has_buttons = has_buttons or control.visible
		control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if enabled else entry.flags
		control.rect_min_size.x = max(0.0, column.rect_size.x - CONTENT_MARGIN) if enabled else entry.width
	_dc_footer_spacer.rect_min_size.y = max(0, CONTENT_MARGIN - column.get_constant("separation"))
	_dc_footer_spacer.visible = enabled and has_buttons


func display_item_data(item_data: ItemParentData, attachment: Control, is_inventory_element: = false) -> void:
	_dc_owned = is_inventory_element
	_panel._item_description.set_meta("dc_item_owned", is_inventory_element)
	.display_item_data(item_data, attachment, is_inventory_element)
	_dc_refresh_advice()
	_dc_sync_popup_layout()


func _dc_sync_popup_layout() -> void:
	if _dc_original_margins.empty():
		return
	var enabled = Settings.enabled("wide_tooltips")
	var margin = _panel._global_container
	var style = _panel.get_stylebox("panel").duplicate()
	for side in ["left", "top", "right", "bottom"]:
		var padding = CONTENT_MARGIN if side in ["left", "top"] else 0
		margin.add_constant_override("margin_" + side, padding if enabled else _dc_original_margins[side])
		style.set("content_margin_" + side, 0.0 if enabled else _dc_original_style_margins[side])
	_panel.add_stylebox_override("panel", style)
	var description = _panel._item_description
	var header = description.get_node("HBoxContainer")
	description.add_constant_override("separation", 0 if enabled else _dc_original_description_separation)
	header.rect_min_size.y = header.get_minimum_size().y + HEADER_GAP if enabled else _dc_original_header_min_height
	if _dc_spacer != null:
		_dc_spacer.visible = _dc_spacer_was_visible and not enabled
	_dc_sync_footer()
	_reposition()


func _reposition() -> void:
	var enabled = Settings.enabled("wide_tooltips")
	var width = 455.0 if enabled else 350.0
	rect_min_size.x = min(_get_parent_rect().size.x, width)
	if _panel != null:
		_panel.rect_min_size.x = rect_min_size.x if enabled else _dc_original_panel_width
	._reposition()


func _dc_refresh_advice() -> void:
	if _panel == null or _item_data == null:
		return
	if _dc_advisor == null:
		_dc_advisor = load("res://mods-unpacked/aimuzov-InsightToolkit/core/advisor.gd").new()
	var description = _panel._item_description
	_dc_advisor.clear_description(description)
	if not Settings.enabled("advice") or not _dc_owned or not _item_data is WeaponData or not _discard_button.visible:
		return
	var result = _dc_advisor.evaluate_sale(_item_data, player_index)
	_dc_advisor.write_to_description(description, result)
