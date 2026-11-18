extends Reference

const DIR = "res://mods-unpacked/aimuzov-InsightToolkit/"

var _shop
var _player_index = 0
var _advisor


func _init(shop: Node, player_index: int) -> void:
	_shop = shop
	_player_index = player_index
	_advisor = load(DIR + "core/advisor.gd").new()


func refresh() -> void:
	var container = _shop._get_shop_items_container(_player_index)
	if container == null:
		return
	var enabled = load(DIR + "core/settings.gd").enabled("advice")
	var items = []
	var references = []
	var excluded = []
	var draws = 0
	for shop_item in container._shop_items:
		_advisor.clear_description(shop_item.get_node("%ItemDescription"))
		references.push_back(weakref(shop_item))
		if shop_item.item_data != null:
			excluded.push_back(shop_item.item_data.my_id)
		if shop_item.visible and shop_item.active and shop_item.item_data != null:
			if not shop_item.locked:
				draws += 1
			if enabled:
				items.push_back(shop_item)
	Engine.set_meta("dc_choice_shop_%d" % _player_index, {"owner": weakref(_shop), "items": references, "wave": RunData.current_wave})
	if items.empty():
		return
	var resources = []
	var prices = []
	for shop_item in items:
		resources.push_back(shop_item.item_data)
		prices.push_back(shop_item.value)
	var price = _shop._reroll_price[_player_index]
	var result = _advisor.analyze(resources, prices, _player_index, {"mode": "shop", "price": price,
		"draws": draws, "excluded": excluded, "available": draws > 0 and RunData.get_player_gold(_player_index) >= price})
	for i in items.size():
		_advisor.write_to_description(items[i].get_node("%ItemDescription"), result.cards[i])
