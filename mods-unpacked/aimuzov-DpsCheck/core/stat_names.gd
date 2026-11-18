extends Reference

# Улучшения уровня нарисованы и названы частями тела («Руки», «Сердце»), а статы — нет.
# Даём улучшению имя его стата (ключ STAT_* из переводов игры) и иконку-символ стата.
# Та же иконка идёт в панель «Параметры» и строки эффектов: один набор на всё.
# Исходные имя и иконку храним в meta ресурса, чтобы настройку можно было выключить на лету.

const ART_DIR = "res://mods-unpacked/aimuzov-DpsCheck/art/"
const SETTINGS = "res://mods-unpacked/aimuzov-DpsCheck/core/settings.gd"
const REVAMPED_ICONS = "monoSDE-RevampedIcons"


static func apply() -> void:
	var Settings = load(SETTINGS)
	# RevampedIcons делает то же своими рисунками и переводом: если он включён, не мешаем ему
	if ModLoaderMod.is_mod_loaded(REVAMPED_ICONS):
		return
	var rename = Settings.enabled("stat_upgrade_names")
	var custom_icons = Settings.enabled("stat_icons")
	var cache = {}

	for upgrade in ItemService.upgrades:
		var stat_key = _stat_key(upgrade)
		if stat_key == "":
			continue
		_remember(upgrade, "name")
		_remember(upgrade, "icon")
		var stat_name = stat_key.to_upper()
		upgrade.name = stat_name if rename and _has_translation(stat_name) else upgrade.get_meta("dc_original_name")
		var icon = _icon(stat_key, cache) if custom_icons else null
		upgrade.icon = icon if icon != null else upgrade.get_meta("dc_original_icon")

	# StatData.small_icon рисуют панель «Параметры» и строки эффектов,
	# StatData.icon — крупные места вроде всплывающей подсказки стата
	for stat in ItemService.stats:
		_remember(stat, "icon")
		_remember(stat, "small_icon")
		var icon = _icon(stat.stat_name, cache) if custom_icons else null
		stat.icon = icon if icon != null else stat.get_meta("dc_original_icon")
		stat.small_icon = icon if icon != null else stat.get_meta("dc_original_small_icon")


static func _remember(resource: Resource, property: String) -> void:
	var meta = "dc_original_" + property
	if not resource.has_meta(meta):
		resource.set_meta(meta, resource.get(property))


static func _stat_key(upgrade: Resource) -> String:
	if upgrade.effects.empty():
		return ""
	var key = upgrade.effects[0].key
	return key if key.begins_with("stat_") else ""


static func _has_translation(key: String) -> bool:
	return TranslationServer.translate(key) != key


# PNG лежит в zip мода без импорта Godot, поэтому грузим как Image, а не как ресурс
static func _icon(stat_key: String, cache: Dictionary) -> Texture:
	var path = ART_DIR + "icons/" + stat_key.trim_prefix("stat_") + ".png"
	if cache.has(path):
		return cache[path]
	var texture = null
	var file = File.new()
	if file.file_exists(path):
		var image = Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.new()
			# Как в импорте игровых иконок: фильтрация без mipmap, иначе в мелком размере мыло
			texture.create_from_image(image, Texture.FLAG_FILTER)
			# Описание оружия вставляет иконку по resource_path.
			texture.take_over_path(path)
	cache[path] = texture
	return texture
