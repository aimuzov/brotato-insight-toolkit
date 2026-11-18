extends "res://ui/menus/shop/secondary_stat_container.gd"

const DcTranslations = preload("res://mods-unpacked/aimuzov-DpsCheck/core/translations.gd")

var _dc_player_index = -1


func _ready() -> void:
	add_to_group("dc_short_names")


func update_player_stat(player_index: int) -> void:
	_dc_player_index = player_index
	.update_player_stat(player_index)
	var text_key = custom_text_key if custom_text_key != "" else key
	DcTranslations.compact_stat(text_key, _label, _value)


func _dc_refresh_short_names() -> void:
	if _dc_player_index >= 0:
		update_player_stat(_dc_player_index)
