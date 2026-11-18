extends VBoxContainer

# Урон за волну по каждому оружию и боевому предмету игрока, замена DmgMeter.
# Строка: ячейка с иконкой в рамке редкости и число. Сильнейшие сверху.
# Правые игроки (2 и 4) получают зеркальную раскладку.

const Style = preload("res://mods-unpacked/aimuzov-DpsCheck/ui/style.gd")
const Display = preload("res://mods-unpacked/aimuzov-DpsCheck/core/damage_display.gd")
const Settings = preload("res://mods-unpacked/aimuzov-DpsCheck/core/settings.gd")
const ICON_PANEL = "res://ui/menus/shop/icon_panel.tscn"
const ICON_SIZE = 40
const ICON_SLOT_SIZE = 64
const DAMAGE_FONT_SIZE = 40
const COUNT_FONT_SIZE = 28
const DAMAGE_GAP = 4
const COUNT_INSET = 2
const DIFFERENCE_FONT_SIZE = 24
const DAMAGE_TRACKING = ["DAMAGE_DEALT", "EXPLOSION_DAMAGE_DEALT"]
# Оружие, которое ставит постройки: их урон записан на отдельный предмет
const SPAWNED_ITEMS = {
	"WEAPON_SCREWDRIVER": ["item_landmines"],
	"ITEM_BOT_O_MINE": ["item_landmines"],
}
const WRENCH_TURRETS = ["item_turret", "item_turret_flame", "item_turret_laser", "item_turret_rocket"]

var _player_index = 0
var _right_side = false
# [{data, start, panel, label}]
var _entries = []
var _previous = {}
var _seconds_left = -1.0


func _init(player_index: int) -> void:
	_player_index = player_index
	_right_side = player_index % 2 == 1
	mouse_filter = MOUSE_FILTER_IGNORE
	add_constant_override("separation", 4)
	add_to_group("dc_short_numbers")


# Собирает список в начале волны: значение счётчиков предметов запоминаем,
# дальше показываем прирост, как DmgMeter
func build() -> void:
	_previous = _previous_damage()
	var seen = {}
	for group in Display.weapons(RunData.get_player_weapons(_player_index)):
		_add(group.data, group.members)
		for weapon in group.members:
			_add_spawned(weapon, seen)

	for item in RunData.get_player_items(_player_index):
		_add_spawned(item, seen)
		if seen.has(item.my_id):
			continue
		if DAMAGE_TRACKING.has(item.tracking_text) or item.name == "ITEM_BUILDER_TURRET":
			seen[item.my_id] = true
			_add(item)


func _add_spawned(source: Resource, seen: Dictionary) -> void:
	for item_id in _spawned_item_ids(source):
		if seen.has(item_id):
			continue
		seen[item_id] = true
		var spawned = ItemService.get_item_from_id(Keys.generate_hash(item_id))
		if spawned != null:
			_add(spawned)


func refresh(seconds_left: float = -1.0) -> void:
	_seconds_left = seconds_left
	for entry in _entries:
		entry.value = _damage(entry)
		var formatted = _display_parts(entry.value)
		entry.label.text = formatted.digits
		entry.suffix.text = formatted.suffix
		entry.delta_box.visible = entry.previous != null and (entry.value > float(entry.previous) or (seconds_left >= 0.0 and seconds_left <= 5.0))
		if entry.previous != null:
			var delta = entry.value - float(entry.previous)
			var change = _display_parts(abs(delta))
			entry.difference.digits.text = ("+" if delta > 0 else ("−" if delta < 0 else "")) + change.digits
			entry.difference.suffix.text = change.suffix
			entry.difference.digits.modulate = Color(ProgressData.settings.color_positive) if delta > 0 else (Color(ProgressData.settings.color_negative) if delta < 0 else Style.MUTED)
	_entries.sort_custom(self, "_by_value")
	for i in _entries.size():
		move_child(_entries[i].row, i)


func _display_parts(value: float) -> Dictionary:
	if Settings.enabled("short_numbers"):
		return Display.parts(value)
	return {"digits": Text.get_formatted_number(int(value)), "suffix": ""}


func _dc_refresh_short_numbers() -> void:
	refresh(_seconds_left)


func _add(data: Resource, members: Array = []) -> void:
	var panel = load(ICON_PANEL).instance()
	panel.rect_min_size = Vector2(ICON_SIZE, ICON_SIZE)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var icon_slot = CenterContainer.new()
	icon_slot.rect_min_size = Vector2(ICON_SLOT_SIZE, ICON_SIZE)
	icon_slot.mouse_filter = MOUSE_FILTER_IGNORE
	icon_slot.add_child(panel)

	var total = _number_pair(DAMAGE_FONT_SIZE)
	var difference = _number_pair(DIFFERENCE_FONT_SIZE)
	var delta_box = HBoxContainer.new()
	delta_box.mouse_filter = MOUSE_FILTER_IGNORE
	delta_box.add_constant_override("separation", 0)
	for part in [Style.label("(", DIFFERENCE_FONT_SIZE, Style.MUTED), difference.box, Style.label(")", DIFFERENCE_FONT_SIZE, Style.MUTED)]:
		if part is Label:
			part.valign = Label.VALIGN_CENTER
		delta_box.add_child(part)
	delta_box.hide()

	var row = HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_constant_override("separation", DAMAGE_GAP)
	row.alignment = BoxContainer.ALIGN_END if _right_side else BoxContainer.ALIGN_BEGIN
	var parts = [icon_slot, total.box, delta_box]
	if _right_side:
		parts.invert()
	for part in parts:
		row.add_child(part)
	add_child(row)

	# Иконку и рамку ставим после add_child: IconPanel берёт узлы в onready
	panel.get_node("Icon").texture = data.icon
	panel._update_stylebox(data.is_cursed, data.tier)
	_set_count(panel, members.size())

	var previous = _previous.get(Display.family(data)) if data is WeaponData else null
	var entry = {"data": data, "members": members, "row": row, "panel": panel, "label": total.digits, "suffix": total.suffix,
		"difference": difference, "delta_box": delta_box, "previous": previous, "value": 0.0, "start": 0.0}
	if not data is WeaponData:
		entry.start = _tracked(data)
	_entries.push_back(entry)


func _number_pair(size: int) -> Dictionary:
	var box = HBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_constant_override("separation", 0)
	var digits = Style.label("", size)
	var suffix = Style.label("", size, Style.MUTED)
	for label in [digits, suffix]:
		label.set_meta("dc_numbers_formatted", true)
		label.valign = Label.VALIGN_CENTER
		box.add_child(label)
	return {"box": box, "digits": digits, "suffix": suffix}


func _previous_damage() -> Dictionary:
	if RunData.current_wave <= 1 or not RunData.has_meta("dc_combat_history"):
		return {}
	var history = RunData.get_meta("dc_combat_history")
	var previous = history.get(RunData.current_wave - 1)
	if previous == null or previous.duration <= 0:
		return {}
	var totals = previous.get("weapon_damage")
	if not totals is Array or _player_index >= totals.size():
		return {}
	return totals[_player_index].duplicate()


func _set_count(panel: Control, amount: int) -> void:
	panel.set_count(1)
	var clip = Control.new()
	clip.name = "DcWeaponCount"
	clip.mouse_filter = MOUSE_FILTER_IGNORE
	clip.rect_clip_content = true
	panel.add_child(clip)
	clip.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	clip.margin_left = COUNT_INSET
	clip.margin_top = COUNT_INSET
	clip.margin_right = -COUNT_INSET
	clip.margin_bottom = 0.0
	var count = Style.label(str(amount), COUNT_FONT_SIZE)
	clip.add_child(count)
	count.text = str(amount)
	clip.visible = amount > 1
	count.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_WIDE)
	count.margin_top = -count.get_font("font").get_height() + 2.0
	count.margin_bottom = 2.0
	count.align = Label.ALIGN_LEFT
	count.valign = Label.VALIGN_BOTTOM
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.clip_text = true


func _damage(entry: Dictionary) -> float:
	if entry.data is WeaponData:
		return Display.damage(entry.members)
	return max(0.0, _tracked(entry.data) - entry.start)


# Счётчик предмета в RunData: число или массив чисел по экземплярам
func _tracked(item: Resource) -> float:
	var tracked = RunData.tracked_item_effects[_player_index].get(item.my_id_hash, 0)
	if tracked is Array:
		var total = 0.0
		for value in tracked:
			total += value
		return total
	return float(tracked)


func _spawned_item_ids(source: Resource) -> Array:
	if source.name == "WEAPON_WRENCH":
		return [WRENCH_TURRETS[int(clamp(source.tier, 0, WRENCH_TURRETS.size() - 1))]]
	return SPAWNED_ITEMS.get(source.name, [])


func _by_value(a: Dictionary, b: Dictionary) -> bool:
	return a.value > b.value
