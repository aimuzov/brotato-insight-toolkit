extends Reference

const ACTIVE_META = "dc_russian_translation"
const Settings = preload("res://mods-unpacked/aimuzov-DpsCheck/core/settings.gd")
const LocalizedTranslation = preload("res://mods-unpacked/aimuzov-DpsCheck/core/localized_translation.gd")
const ENGLISH = "res://resources/translations/translations.en.translation"
const ORIGINAL_RUSSIAN = "res://resources/translations/translations.ru.translation"
const CATALOGUE_DIR = "res://mods-unpacked/aimuzov-DpsCheck/localization/"

const TEXT = {
	"PRIMARY": "База",
	"SECONDARY": "Допы",
	"STAT_MELEE_DAMAGE": "Ближний",
	"STAT_RANGED_DAMAGE": "Дальний",
	"STAT_ELEMENTAL_DAMAGE": "Стихийный",
	"STAT_MAX_HP": "ХП",
	"STAT_HP_REGENERATION": "Реген",
	"MELEE": "Ближний",
	"RANGED": "Дальний",
	"LIFESTEAL": "Кража",
	"CRITICAL": "Крит. урон",
	"STAT_LIFESTEAL": "% Кража",
	"STAT_PERCENT_DAMAGE": "% Урон",
	"STAT_ATTACK_SPEED": "% Скор. атаки",
	"STAT_CRIT_CHANCE": "% Крит",
	"STAT_CRIT_DAMAGE": "% Крит. урон",
	"STAT_DODGE": "% Уклонение",
	"STAT_SPEED": "% Скорость",
	"XP_GAIN": "% Бонус опыта",
	"PICKUP_RANGE": "% Радиус сбора",
	"EXPLOSION_DAMAGE": "% Урон взрывов",
	"PIERCING_DAMAGE": "% Урон пробивания",
	"BOUNCE_DAMAGE": "% Урон отскоков",
	"DAMAGE_AGAINST_BOSSES": "% Урон боссам",
	"STRUCTURE_ATTACK_SPEED": "% Скор. атаки построек",
	"STRUCTURE_RANGE": "Дальность построек",
	"SORT_BY_WEAPON_DAMAGE": "По урону",
	"SORT_BY_WEAPON_RANGE": "По дальности",
	"SORT_BY_WEAPON_RELOAD_TIME": "По перезарядке",
	"COOLDOWN": "Перезарядка",
}


static func apply() -> void:
	if Engine.has_meta(ACTIVE_META):
		TranslationServer.remove_translation(Engine.get_meta(ACTIVE_META))
	var original = load(ORIGINAL_RUSSIAN)
	var catalogue = {"by_key": {}, "by_source": {}}
	if Settings.enabled("corrected_translation"):
		var variant = "ru_short" if Settings.enabled("short_names") else "ru_full"
		catalogue = _catalogue(variant)
	else:
		if Settings.enabled("short_names"):
			catalogue.by_key = TEXT.duplicate()
		catalogue.by_key["EFFECT_GOLD_DROPS"] = "Материалы: {0}"
	var translation = LocalizedTranslation.new(catalogue, load(ENGLISH), original)
	TranslationServer.remove_translation(original)
	TranslationServer.add_translation(translation)
	Engine.set_meta(ACTIVE_META, translation)


static func compact_stat(key: String, label: Button, value: Label) -> void:
	if not TranslationServer.get_locale().begins_with("ru"):
		return
	if not Settings.enabled("short_names") and not Settings.enabled("corrected_translation"):
		return
	var text = TranslationServer.translate(key)
	label.text = text.trim_prefix("% ")
	if text.begins_with("% "):
		value.text = value.text.replace(" | ", "% | ") + "%"


static func text(key: String) -> String:
	return TranslationServer.translate(key)


static func restore_original() -> void:
	if Engine.has_meta(ACTIVE_META):
		TranslationServer.remove_translation(Engine.get_meta(ACTIVE_META))
		Engine.remove_meta(ACTIVE_META)
	TranslationServer.add_translation(load(ORIGINAL_RUSSIAN))


static func _catalogue(variant: String) -> Dictionary:
	var meta = "dc_catalogue_" + variant
	if Engine.has_meta(meta):
		return Engine.get_meta(meta)
	var file = File.new()
	if file.open(CATALOGUE_DIR + variant + ".json", File.READ) != OK:
		printerr("DpsCheck: cannot open translation catalogue ", variant)
		return {"by_key": {}, "by_source": {}}
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or not parsed.result is Dictionary or not parsed.result.has_all(["by_key", "by_source"]):
		printerr("DpsCheck: invalid translation catalogue ", variant)
		return {"by_key": {}, "by_source": {}}
	Engine.set_meta(meta, parsed.result)
	return parsed.result
