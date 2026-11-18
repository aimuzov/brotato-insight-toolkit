extends "res://ui/menus/shop/shop.gd"

const DC_DIR = "res://mods-unpacked/aimuzov-InsightToolkit/"

var _dc_overlay


func _ready() -> void:
	add_to_group("dc_item_advice")
	_dc_overlay = load(DC_DIR + "core/shop_overlay.gd").new(self, 0)
	call_deferred("_dc_refresh_advice")


func _update_stats(player_index: = - 1) -> void:
	._update_stats(player_index)
	call_deferred("_dc_refresh_advice")


func _dc_refresh_advice() -> void:
	if _dc_overlay != null:
		_dc_overlay.refresh()
