extends VBoxContainer

const DIR = "res://mods-unpacked/aimuzov-DpsCheck/"
const Style = preload("res://mods-unpacked/aimuzov-DpsCheck/ui/style.gd")

var player_index = 0
var _waves: OptionButton
var _summary: Label
var _rows


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	add_constant_override("separation", 10)
	_waves = OptionButton.new()
	_waves.add_font_override("font", Style.font(22))
	_waves.connect("item_selected", self, "_on_wave_selected")
	add_child(_waves)

	_summary = Style.label("", 20, Style.MUTED)
	_summary.autowrap = true
	add_child(_summary)

	var scroll = ScrollContainer.new()
	scroll.rect_min_size.y = 300
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.scroll_horizontal_enabled = false
	add_child(scroll)
	_rows = load(DIR + "ui/creep_panel.gd").new(0)
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	connect("visibility_changed", self, "refresh")
	refresh()


func refresh() -> void:
	if _waves == null:
		return
	var selected = _waves.get_selected_id()
	var history = _history()
	var waves = history.keys()
	waves.sort()
	_waves.clear()
	for wave in waves:
		_waves.add_item("Волна %d" % wave, wave)
	if not waves.empty():
		var index = waves.find(selected)
		_waves.select(index if index >= 0 else waves.size() - 1)
	_waves.disabled = waves.empty()
	_on_wave_selected(_waves.selected)


func _on_wave_selected(_index: int) -> void:
	var log_data = _history().get(_waves.get_selected_id())
	var rows = []
	var kills = 0
	if log_data != null and player_index >= 0 and player_index < log_data.players.size():
		rows = log_data.top_rows(player_index, max(1, log_data.players[player_index].size()))
		for row in rows:
			kills += row.kills
	_summary.text = "Убито: %d" % kills if not rows.empty() else "За эту волну данных пока нет"
	_rows.set_rows(rows)


func _history() -> Dictionary:
	return RunData.get_meta("dc_combat_history") if RunData.has_meta("dc_combat_history") else {}
