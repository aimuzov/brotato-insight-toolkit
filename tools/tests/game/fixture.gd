extends Control
var player_index = 0
var _reroll_price = 4
var _reroll_button = Button.new()
var _discard_button = Button.new()
var _level = 5
var _item_description
var _item_data
var uis = []
var _shop_items = []
var upgrade_data
var item_data
var active = true
var value = 5
var locked = false
var button = Button.new()
var _upgrades_container = Control.new()
func _init():
 add_child(_reroll_button)
 add_child(_discard_button)
 add_child(button)
 add_child(_upgrades_container)
func _get_upgrade_uis():
 return uis
