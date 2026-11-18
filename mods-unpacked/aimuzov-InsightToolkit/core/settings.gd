extends Reference

# Настройки мода без ModOptions: значения по умолчанию плюс JSON в профиле игры.
# Видимые настройки меняются в игре: «Настройки» → «Геймплей», раздел мода.

const PATH = "user://aimuzov-insight-toolkit.json"
const CACHE_META = "aimuzov_insight_toolkit_settings"

const DEFAULTS = {
	"advice": false,
	# Замена сторонних модов
	"damage_meter": true,
	"creep_stats": true,
	"wide_camera": true,
	"wide_camera_zoom": 1.0,
	"wide_camera_toggle": "mouse_middle",
	"stat_upgrade_names": true,
	"short_names": true,
	"short_numbers": true,
	"corrected_translation": true,
	"stat_totals": true,
	"stat_icons": true,
	"range_area": false,
	"wave_speed": 1,
	"wide_tooltips": true,
}

# Что показываем в меню игры: [ключ, подпись]
const MENU = [
	["advice", "Анализатор выбора"],
	["damage_meter", "Урон от оружия на экране"],
	["creep_stats", "Статистика крипов"],
	["wide_camera", "Закрепить камеру в одиночке"],
	["stat_upgrade_names", "Улучшения называются по статам"],
	["short_names", "Короткие названия"],
	["short_numbers", "Короткие числа"],
	["corrected_translation", "Исправленный перевод"],
	["stat_totals", "Итоговые значения статов"],
	["wide_tooltips", "Широкие подсказки"],
	["stat_icons", "Свои иконки статов"],
	["range_area", "Круги дальности атаки вокруг персонажа"],
]


static func value(key: String):
	var data = _load()
	return data[key] if data.has(key) else DEFAULTS.get(key)


static func enabled(key: String) -> bool:
	return bool(value(key))


static func wave_speed() -> int:
	var speed = value("wave_speed")
	return int(speed) if speed in [1, 2, 3, 4] else 1


# Меняет значение и сразу пишет файл; кеш общий, поэтому все места видят новое значение
static func set_value(key: String, new_value) -> void:
	var data = _load()
	data[key] = new_value
	var file = File.new()
	if file.open(PATH, File.WRITE) == OK:
		file.store_string(JSON.print(data, "\t", true))
		file.close()
	else:
		printerr("aimuzov-InsightToolkit: can't write %s" % PATH)


static func _load() -> Dictionary:
	if Engine.has_meta(CACHE_META):
		return Engine.get_meta(CACHE_META)

	var data = DEFAULTS.duplicate()
	var file = File.new()
	if file.file_exists(PATH) and file.open(PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and parsed.result is Dictionary:
			for key in parsed.result:
				data[key] = parsed.result[key]
		else:
			printerr("aimuzov-InsightToolkit: can't parse %s, using defaults" % PATH)

	Engine.set_meta(CACHE_META, data)
	return data
