extends Control

# Заглушка res://ui/menus/shop/shop.gd и coop_shop.gd для проверки расширений


func _update_stats(_player_index: = - 1) -> void:
	pass


func _get_shop_items_container(_player_index: int):
	return null


func _get_coop_player_container(_player_index: int):
	return null
