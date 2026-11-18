extends Reference

# Раздел мода в «Настройки» → «Геймплей»: такие же переключатели, как у игры.
# Скрипт меню (menu_options.gd) расширить нельзя: при перезагрузке его байткод
# не разбирается, поэтому дописываем раздел в уже готовое меню снаружи.

const DIR = "res://mods-unpacked/aimuzov-InsightToolkit/"
const FONT = "res://resources/fonts/actual/base/font_40_outline.tres"
const HOVER = "res://resources/themes/button_styles/button_hover.tres"
const BUTTON_SCRIPT = "res://ui/menus/global/my_menu_button.gd"
const MARKER = "DcOptionsSection"


static func inject(menu: Node) -> void:
	var container = menu.get("gameplayVBoxContainer")
	if container == null or container.has_node(MARKER):
		return
	var damage_display = menu.get("damage_display_button")
	if damage_display != null:
		damage_display.add_to_group("dc_damage_display_options")
	var Settings = load(DIR + "core/settings.gd")

	var header = Label.new()
	header.name = MARKER
	header.text = "Brotato Insight Toolkit"
	header.add_font_override("font", load(FONT))
	header.modulate = Color(1, 1, 1, 0.7)
	container.add_child(header)

	var handler = Handler.new()
	for item in Settings.MENU:
		var button = CheckButton.new()
		button.set_script(load(BUTTON_SCRIPT))
		button.text = item[1]
		button.add_font_override("font", load(FONT))
		button.add_stylebox_override("hover_pressed", load(HOVER))
		button.pressed = Settings.enabled(item[0])
		# Обработчик живёт, пока на него ссылается кнопка через meta
		button.set_meta("dc_handler", handler)
		button.connect("toggled", handler, "on_toggled", [item[0]])
		container.add_child(button)

	var speed = load("res://ui/menus/global/slider_option.tscn").instance()
	speed.name = "DcWaveSpeed"
	container.add_child(speed)
	speed._label.text = "Скорость волны"
	speed._label.add_font_override("font", load(FONT))
	speed._value.add_font_override("font", load(FONT))
	speed._slider.min_value = 1
	speed._slider.max_value = 4
	speed._slider.step = 1
	speed._slider.rounded = true
	speed._slider.tick_count = 4
	speed._slider.ticks_on_borders = true
	speed.set_value(Settings.wave_speed())
	speed._value.text = "×%d" % Settings.wave_speed()
	speed.set_meta("dc_handler", handler)
	speed.connect("value_changed", handler, "on_wave_speed_changed", [speed])
	speed.add_to_group("dc_wave_speed_options")


class Handler:
	extends Reference

	const DIR = "res://mods-unpacked/aimuzov-InsightToolkit/"

	func on_wave_speed_changed(value: float, option: Node) -> void:
		var speed = int(value)
		option._value.text = "×%d" % speed
		load(DIR + "core/settings.gd").set_value("wave_speed", speed)
		Engine.get_main_loop().call_group("dc_wave_speed", "sync")

	func on_toggled(button_pressed: bool, key: String) -> void:
		load(DIR + "core/settings.gd").set_value(key, button_pressed)
		if key == "short_numbers":
			Engine.get_main_loop().call_group("dc_short_numbers", "_dc_refresh_short_numbers")
		if key == "short_names" or key == "corrected_translation":
			load(DIR + "core/translations.gd").apply()
		if key == "short_names" or key == "corrected_translation" or key == "stat_totals":
			Engine.get_main_loop().call_group("dc_short_names", "_dc_refresh_short_names")
		if key == "wide_tooltips":
			Engine.get_main_loop().call_group("dc_wide_tooltips", "_dc_sync_popup_layout")
		if key == "creep_stats":
			Engine.get_main_loop().call_group("dc_creep_stats", "_dc_sync_creep_setting")
		# Имена и иконки — это данные игры, их пересобираем сразу
		if key == "stat_upgrade_names" or key == "stat_icons":
			load(DIR + "core/stat_names.gd").apply()
		if key in ["advice", "short_names", "corrected_translation", "stat_totals", "stat_upgrade_names", "stat_icons"]:
			Engine.get_main_loop().call_group("dc_item_advice", "_dc_refresh_advice")
