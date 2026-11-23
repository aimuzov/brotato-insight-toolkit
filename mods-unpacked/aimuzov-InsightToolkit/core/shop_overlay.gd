extends Reference

const Style = preload("../ui/style.gd")
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
	var reroll = _shop._get_reroll_button(_player_index)
	var go = _shop._get_go_button(_player_index)
	Style.mark_choice(reroll, false)
	Style.mark_choice(go, false)
	if container == null:
		return
	var enabled = load(DIR + "core/settings.gd").enabled("advice")
	var items = []
	var references = []
	var excluded = []
	var draws = 0
	for shop_item in container._shop_items:
		Style.mark_choice(shop_item.get_node("PanelContainer"), false)
		references.push_back(weakref(shop_item))
		if shop_item.item_data != null:
			excluded.push_back(shop_item.item_data.my_id)
		if not shop_item.locked:
			draws += 1
		if enabled and shop_item.visible and shop_item.active and shop_item.item_data != null:
			items.push_back(shop_item)
	Engine.set_meta("dc_choice_shop_%d" % _player_index, {"owner": weakref(_shop), "items": references, "wave": RunData.current_wave})
	if not enabled:
		return
	var resources = []
	var prices = []
	for shop_item in items:
		resources.push_back(shop_item.item_data)
		prices.push_back(shop_item.value)
	var price = _shop._reroll_price[_player_index]
	var result = _advisor.analyze(resources, prices, _player_index, {"mode": "shop", "price": price,
		"draws": draws, "excluded": excluded, "available": reroll.visible and not reroll.get("disabled") and draws > 0 and RunData.get_player_gold(_player_index) >= price})
	var save = not result.roll_wins
	for i in items.size():
		var card = result.cards[i]
		Style.mark_choice(items[i].get_node("PanelContainer"), card.recommended)
		if card.recommended:
			save = false
	Style.mark_choice(reroll, result.roll_wins)
	Style.mark_choice(go, save and go.visible and not go.get("disabled"))
