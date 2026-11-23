extends "res://ui/menus/shop/coop_shop.gd"

const DC_DIR = "res://mods-unpacked/aimuzov-InsightToolkit/"

var _dc_overlays = []


func _ready() -> void:
	add_to_group("dc_item_advice")
	for player_index in RunData.get_player_count():
		_dc_overlays.push_back(load(DC_DIR + "core/shop_overlay.gd").new(self, player_index))
	call_deferred("_dc_show_tumor_notification")
	call_deferred("_dc_refresh_advice")


func _update_stats(player_index: = - 1) -> void:
	._update_stats(player_index)
	call_deferred("_dc_refresh_advice")


func _dc_refresh_advice() -> void:
	for overlay in _dc_overlays:
		overlay.refresh()


func _dc_show_tumor_notification() -> void:
	for index in RunData.get_player_count():
		preload("res://mods-unpacked/aimuzov-InsightToolkit/ui/tumor_notification.gd").show_in_shop(self, index)
