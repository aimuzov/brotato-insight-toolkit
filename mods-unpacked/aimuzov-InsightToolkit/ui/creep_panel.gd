extends VBoxContainer

# Таблица по типам врагов для одного игрока, в духе DmgMeter.
# Строка: сколько убито, иконка моба, урон по ним, урон от них.
# Над строками легенда, правые игроки (2 и 4) получают зеркальную раскладку.

const Style = preload("res://mods-unpacked/aimuzov-InsightToolkit/ui/style.gd")
const ICON_SIZE = 36
const STAT_ICON_SIZE = 20
const KILLS_WIDTH = 34

var _right_side = false
var _legend: HBoxContainer
var _rows = []


func _init(player_index: int) -> void:
	_right_side = player_index % 2 == 1
	mouse_filter = MOUSE_FILTER_IGNORE
	add_constant_override("separation", 2)
	_legend = _make_legend()
	add_child(_legend)


func set_rows(rows: Array) -> void:
	_legend.visible = rows.size() > 0
	while _rows.size() < rows.size():
		_rows.push_back(_make_row())
	for i in _rows.size():
		var row = _rows[i]
		row.node.visible = i < rows.size()
		if row.node.visible:
			_fill(row, rows[i])


func _make_legend() -> HBoxContainer:
	var parts = [
		Style.label("убито", 16, Style.MUTED),
		Style.icon(Style.stat_icon(Keys.stat_percent_damage_hash), 16),
		Style.label("нанёс", 16, Style.MUTED),
		Style.icon(Style.stat_icon(Keys.stat_max_hp_hash), 16),
		Style.label("получил", 16, Style.MUTED),
	]
	return _hbox(parts, 6)


func _make_row() -> Dictionary:
	var kills = Style.label("", 16, Style.MUTED)
	kills.rect_min_size = Vector2(KILLS_WIDTH, 0)
	kills.align = Label.ALIGN_LEFT if _right_side else Label.ALIGN_RIGHT
	kills.valign = Label.VALIGN_CENTER

	var icon = Style.icon(null, ICON_SIZE)

	var dealt = Style.label("", 20)
	dealt.valign = Label.VALIGN_CENTER
	var dealt_icon = Style.icon(Style.stat_icon(Keys.stat_percent_damage_hash), STAT_ICON_SIZE)

	var taken = Style.label("", 20, Style.BAD)
	taken.valign = Label.VALIGN_CENTER
	var taken_icon = Style.icon(Style.stat_icon(Keys.stat_max_hp_hash), STAT_ICON_SIZE)

	var node = _hbox([kills, icon, dealt_icon, dealt, taken_icon, taken], 6)
	add_child(node)
	return {"node": node, "kills": kills, "icon": icon, "dealt": dealt, "taken": taken, "taken_icon": taken_icon}


# Слева направо для левого игрока, справа налево для правого
func _hbox(parts: Array, separation: int) -> HBoxContainer:
	var box = HBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_constant_override("separation", separation)
	box.alignment = BoxContainer.ALIGN_END if _right_side else BoxContainer.ALIGN_BEGIN
	if _right_side:
		parts.invert()
	for part in parts:
		box.add_child(part)
	return box


func _fill(row: Dictionary, data: Dictionary) -> void:
	row.icon.texture = data.icon
	row.kills.text = "x%d" % data.kills if data.kills > 0 else ""
	row.dealt.text = Style.num(data.dealt)
	row.taken.text = Style.num(data.taken)
	var hurt = data.taken >= 1.0
	row.taken.visible = hurt
	row.taken_icon.visible = hurt
