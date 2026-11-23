extends PanelContainer

const Style = preload("style.gd")
const BASELINE = "dc_tumor_before_wave"

var _lines: Array
var _message = RichTextLabel.new()
var _index = 0


static func _snapshot(player_index: int) -> Dictionary:
	var state = {"count": 0, "effects": []}
	for item in RunData.get_player_items(player_index):
		if item.my_id != "item_tumor":
			continue
		for effect in item.effects:
			if effect.text_key.to_upper() == "EFFECT_TUMOR_MUTATION_COUNT":
				state.count = effect.value
			else:
				state.effects.append(effect)
		break
	return state


static func remember(player_index: int) -> void:
	var state = _snapshot(player_index)
	var signatures = []
	for effect in state.effects:
		signatures.append(JSON.print(effect.serialize(), "", true))
	RunData.players_data[player_index].set_meta(BASELINE, {"count": state.count, "effects": signatures})


static func take_changes(player_index: int) -> Array:
	var player = RunData.players_data[player_index]
	if not player.has_meta(BASELINE):
		return []
	var before = player.get_meta(BASELINE)
	player.remove_meta(BASELINE)
	var current = _snapshot(player_index)
	if current.count <= before.count:
		return []
	var lines = []
	var evolution = ""
	for effect in current.effects:
		var signature = JSON.print(effect.serialize(), "", true)
		var previous = before.effects.find(signature)
		if previous >= 0:
			before.effects.remove(previous)
			continue
		var text = effect.get_text(player_index)
		if text == "" or text == "[EMPTY]":
			continue
		# Игра добавляет изменение эволюции при каждой мутации.
		if effect.key == "stat_evolution":
			evolution = text
		else:
			lines.push_back(text)
	if evolution != "":
		lines.push_back(evolution)
	if lines.empty():
		lines.push_back("Мутаций: %d → %d" % [before.count, current.count])
	return lines


static func show_in_shop(shop: Node, player_index: int) -> void:
	var container = shop._get_shop_items_container(player_index)
	if container == null:
		return
	var lines = take_changes(player_index)
	if lines.empty():
		return
	var row = container.get_parent()
	var notice = load("res://mods-unpacked/aimuzov-InsightToolkit/ui/tumor_notification.gd").new(lines)
	row.get_parent().add_child(notice)
	row.get_parent().move_child(notice, row.get_index() + 1)


func _init(lines: Array) -> void:
	_lines = lines
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_mode = Node.PAUSE_MODE_PROCESS
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(Style.label("Новая мутация «Опухоли»", 20, Style.BEST))
	_message.bbcode_enabled = true
	_message.fit_content_height = true
	_message.scroll_active = false
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.add_font_override("normal_font", Style.font(18))
	column.add_child(_message)


func _ready() -> void:
	_next()
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.connect("timeout", self, "_next")
	add_child(timer)
	timer.start()


func _next() -> void:
	if _index >= _lines.size():
		queue_free()
		return
	_message.bbcode_text = "Теперь: " + _lines[_index]
	_index += 1
