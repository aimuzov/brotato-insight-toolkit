extends Node
var _reroll_price = [4]
var container
func _get_shop_items_container(_index):
 return container
var reroll = Button.new()
var go = Button.new()
func _init():
 add_child(reroll)
 add_child(go)
func _get_reroll_button(_index):
 return reroll
func _get_go_button(_index):
 return go
