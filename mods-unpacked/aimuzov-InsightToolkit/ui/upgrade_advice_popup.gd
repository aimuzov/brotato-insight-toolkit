extends CanvasLayer

const Settings = preload("res://mods-unpacked/aimuzov-InsightToolkit/core/settings.gd")
const WIDTH = 455.0
const GAP = 12.0
const PADDING = 16

var _container
var _cards = []
var _current_card
var _panel = PanelContainer.new()
var _content = VBoxContainer.new()
var _mouse_mode = false


func _init(container) -> void:
	_container = container
	layer = 100
	pause_mode = PAUSE_MODE_PROCESS
	add_child(_panel)
	var margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_constant_override("margin_" + side, PADDING)
	_panel.add_child(margin)
	margin.add_child(_content)
	_ignore_input(_panel)
	_panel.hide()


func set_cards(cards: Array, results: Array, advisor) -> void:
	clear()
	for index in min(cards.size(), results.size()):
		var card = cards[index]
		var description = card.get_node("%UpgradeDescription")
		_cards.push_back({"card": weakref(card), "resource": card.upgrade_data.get_instance_id(),
			"version": _version(description), "lines": advisor.describe_lines(results[index])})
	refresh()


func clear() -> void:
	_cards.clear()
	_current_card = null
	_panel.hide()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.length_squared() > 0:
		_mouse_mode = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_mouse_mode = false
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
		_mouse_mode = false


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if RunData.is_coop_run or not Settings.enabled("advice") or not is_instance_valid(_container) or not _container.is_visible_in_tree() or not _container._upgrades_container.is_visible_in_tree():
		_hide()
		return
	var focused = Utils.get_player_focused_control(_container, _container.player_index, _container.get("focus_emulator"))
	for entry in _cards:
		var card = entry.card.get_ref()
		if not is_instance_valid(card) or card.is_queued_for_deletion() or not card.is_visible_in_tree() or card.upgrade_data == null:
			continue
		var selected = false
		if _mouse_mode:
			selected = card.get_global_rect().has_point(card.get_global_mouse_position())
		elif is_instance_valid(focused):
			selected = focused == card or card.is_a_parent_of(focused)
		if not selected:
			continue
		var description = card.get_node("%UpgradeDescription")
		if card.upgrade_data.get_instance_id() != entry.resource or _version(description) != entry.version:
			break
		if _current_card != card:
			_render(card, description, entry.lines)
		_panel.show()
		_layout(card)
		return
	_hide()


func _hide() -> void:
	_current_card = null
	_panel.hide()


func _render(card: Control, description: Node, lines: Array) -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_current_card = card
	_panel.theme = card.theme
	_panel.add_stylebox_override("panel", card.get_stylebox("panel").duplicate())
	for line in lines:
		var effect_line = description.effect_line.instance()
		_content.add_child(effect_line)
		effect_line._display_special_text(line[0], line[1])
		_ignore_input(effect_line)


func _layout(card: Control) -> void:
	var bounds = card.get_viewport_rect().grow(-GAP)
	_panel.rect_min_size.x = min(WIDTH, bounds.size.x)
	_panel.rect_size = Vector2(_panel.rect_min_size.x, _panel.get_combined_minimum_size().y)
	_panel.rect_position = position_for(card.get_global_rect(), _panel.rect_size, bounds)


static func position_for(card: Rect2, size: Vector2, bounds: Rect2) -> Vector2:
	var x = card.end.x + GAP
	if x + size.x > bounds.end.x:
		x = card.position.x - GAP - size.x
	return Vector2(clamp(x, bounds.position.x, max(bounds.position.x, bounds.end.x - size.x)),
		clamp(card.position.y, bounds.position.y, max(bounds.position.y, bounds.end.y - size.y)))


static func _version(description: Node) -> int:
	return int(description.get_meta("dc_description_version")) if description.has_meta("dc_description_version") else 0


static func _ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_ignore_input(child)
