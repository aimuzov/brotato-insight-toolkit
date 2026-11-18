extends "res://ui/menus/shop/meca_parts_ui.gd"


func _on_focus_entered() -> void:
	._on_focus_entered()
	focus_neighbour_left = NodePath(".")
	var player_index = FocusEmulatorSignal.get_player_index(self)
	if player_index < 0:
		return
	var shop = get_parent()
	while shop != null and not shop.has_method("_get_gear_container"):
		shop = shop.get_parent()
	if shop == null:
		return
	var gear = shop._get_gear_container(player_index)
	if gear == null:
		return
	var weapons = gear.weapons_container._elements
	for weapon in weapons.get_children():
		if not weapon.is_queued_for_deletion() and weapon.focus_mode != Control.FOCUS_NONE:
			focus_neighbour_left = get_path_to(weapon)
			return
