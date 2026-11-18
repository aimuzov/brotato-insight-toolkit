extends Node

const DIR = "res://mods-unpacked/aimuzov-DpsCheck/"
const Fixture = preload("res://fixture.gd")
const Description = preload("res://description.gd")
var checks = 0
var failures = 0


func check(actual, expected, label):
	checks += 1
	if actual != expected:
		failures += 1
		printerr("FAIL ", label, ": ", actual, " expected ", expected)


func scalar(key, amount):
	var resource = Effect.new()
	resource.key = key
	resource.key_hash = Keys.generate_hash(key)
	resource.value = amount
	return resource


func object(id, effects):
	var resource = ItemParentData.new()
	resource.my_id = id
	resource.my_id_hash = Keys.generate_hash(id)
	resource.effects = effects
	return resource


func card(data, name):
	var node = Fixture.new()
	node.item_data = data
	node.upgrade_data = data
	var description = Description.new()
	description.name = name
	node.add_child(description)
	description.owner = node
	description.unique_name_in_owner = true
	add_child(node)
	return node


func _ready():
	call_deferred("run")


func run():
	var NumberSettings = load(DIR+"core/settings.gd")
	NumberSettings.set_value("short_numbers",true)
	check(NumberSettings.DEFAULTS.short_numbers,true,"short numbers enabled by default")
	check(["short_numbers","Короткие числа"] in NumberSettings.MENU,true,"number format toggle exposed in settings")
	var compact = load(DIR+"core/compact_numbers.gd").new()
	for pair in [
		["999", "999"], ["1000", "1k"], ["12000/30000", "12k/30k"],
		["Материалы: 1,500,000", "Материалы: 1.5kk"], ["-2500 ХП", "-2.5k ХП"],
		["+1234.5%", "+1.2k%"], ["1 250", "1.3k"], ["1\u00a0250", "1.3k"],
		["1000s", "1ks"], ["1e6", "1kk"], ["1.3kkk", "1.3kkk"],
		["[color=#ff1000]2500[/color]", "[color=#ff1000]2.5k[/color]"],
		["[img=1000x1000]res://icons/1000.png[/img] 2000", "[img=1000x1000]res://icons/1000.png[/img] 2k"],
		["1920 x 1080", "1920 x 1080"], ["v1.2.1000.3", "v1.2.1000.3"],
		["18.11.2026", "18.11.2026"], ["2026-11-18", "2026-11-18"],
		["Сид: 123456789", "Сид: 123456789"], ["https://example.test/12345", "https://example.test/12345"],
		["© 2026", "© 2026"], ["#123456", "#123456"],
		["30.25 (шанс 20%)", "30.25 (шанс 20%)"]]:
		var formatted = compact.format(pair[0])
		check(formatted,pair[1],"global compact number "+pair[0])
		check(compact.format(formatted),formatted,"global number formatting is idempotent")
	check(Text.get_formatted_number(12500),"12,500","native Text retains exact ordinary numbers")
	check(Text.get_formatted_number(12500,true),"-12,500","native Text negative flag preserved")
	var filter = load(DIR+"ui/compact_numbers.gd").new()
	var health_label = Label.new()
	health_label.text = "2500 / 12500"
	filter.apply_node(health_label)
	check(health_label.text,"2.5k / 12.5k","direct health HUD labels compacted")
	health_label.text = "3500 / 12500"
	filter.apply_node(health_label)
	check(health_label.text,"3.5k / 12.5k","direct HUD labels refresh after native update")
	add_child(health_label)
	health_label.text = "4500 / 12500"
	filter._track(health_label)
	filter._flush()
	check(health_label.text,"4.5k / 12.5k","queued UI formatting handles newly added labels")
	var price_button = Button.new()
	price_button.text = "Купить 12500"
	price_button.set_meta("cost",12500)
	filter.apply_node(price_button)
	check(price_button.text,"Купить 12.5k","button prices compacted")
	check(price_button.get_meta("cost"),12500,"display formatting leaves actual prices untouched")
	var rich_label = RichTextLabel.new()
	rich_label.bbcode_enabled = true
	rich_label.bbcode_text = "[color=#ff1000]−12500[/color] [img=20x20]res://1000.png[/img]"
	filter.apply_node(rich_label)
	check(rich_label.bbcode_text,"[color=#ff1000]−12.5k[/color] [img=20x20]res://1000.png[/img]","rich stats preserve colors and icons")
	var input = LineEdit.new()
	input.text = "123456"
	filter.apply_node(input)
	check(input.text,"123456","editable numeric fields are not rewritten")
	NumberSettings.set_value("short_numbers",false)
	filter._dc_refresh_short_numbers()
	check(health_label.text,"4500 / 12500","disabling restores exact health values immediately")
	filter.apply_node(price_button)
	check(price_button.text,"Купить 12500","disabling restores original price")
	filter.apply_node(rich_label)
	check(rich_label.bbcode_text,"[color=#ff1000]−12500[/color] [img=20x20]res://1000.png[/img]","disabling restores original BBCode values")
	health_label.text = "9876 / 12500"
	filter.apply_node(health_label)
	check(health_label.text,"9876 / 12500","disabled filter leaves new native values untouched")
	NumberSettings.set_value("short_numbers",true)
	filter._dc_refresh_short_numbers()
	check(health_label.text,"9.9k / 12.5k","reenabling formats current values immediately")
	health_label.text = "9877 / 12500"
	NumberSettings.set_value("short_numbers",false)
	filter._dc_refresh_short_numbers()
	check(health_label.text,"9877 / 12500","disabling does not overwrite a newer native update")
	NumberSettings.set_value("short_numbers",true)
	var first_exact = Label.new()
	first_exact.text = "1234"
	var second_exact = Label.new()
	second_exact.text = "1240"
	filter._track(first_exact)
	filter._track(second_exact)
	filter._flush()
	check(first_exact.text,second_exact.text,"distinct exact values may share compact representation")
	NumberSettings.set_value("short_numbers",false)
	filter._dc_refresh_short_numbers()
	check(first_exact.text,"1234","first rounded value restores independently")
	check(second_exact.text,"1240","second rounded value restores independently")
	first_exact.free()
	second_exact.free()
	NumberSettings.set_value("short_numbers",true)
	var split_number = Label.new()
	split_number.text = "1000"
	split_number.set_meta("dc_numbers_formatted",true)
	filter.apply_node(split_number)
	check(split_number.text,"1000","split meter units are not abbreviated twice")
	split_number.free()
	var formatted_at = OS.get_ticks_msec()
	for i in 1000:
		compact.format("Урон %d / %d" % [1000+i,5000+i])
	print("Compact formatter: 1000 strings in ",OS.get_ticks_msec()-formatted_at," ms")
	check(compact._cache.size()<=512,true,"global formatter cache stays bounded")
	compact.free()
	health_label.free()
	filter._process(0.0)
	check(filter._labels.empty(),true,"destroyed floating labels are removed from registry")
	filter.free()
	price_button.free()
	rich_label.free()
	input.free()
	var Display = load(DIR+"core/damage_display.gd")
	for pair in [[0,"0"],[999,"999"],[1000,"1k"],[1250,"1.3k"],[1000000,"1kk"],[1250000000,"1.3kkk"],[999999,"1kk"]]:
		check(Display.number(pair[0]),pair[1],"compact damage " + str(pair[0]))
	var first_weapon = WeaponData.new()
	first_weapon.tier = 0
	first_weapon.dmg_dealt_last_wave = 1500
	var second_weapon = WeaponData.new()
	second_weapon.tier = 2
	second_weapon.dmg_dealt_last_wave = 2500
	var other_weapon = WeaponData.new()
	other_weapon.weapon_id = "weapon_other"
	var groups = Display.weapons([first_weapon,second_weapon,other_weapon])
	check(groups.size(),2,"same weapon family shares a row")
	check(groups[0].members.size(),2,"group retains both weapon instances")
	check(groups[0].data,second_weapon,"highest weapon tier represents group")
	check(Display.damage(groups[0].members),4000.0,"group sums actual per-instance damage")
	var meter = load(DIR+"ui/damage_meter.gd").new(0)
	check(meter._damage(groups[0]),4000.0,"meter reads grouped weapon damage")
	var TestStyle = load(DIR+"ui/style.gd")
	var gold_ui = HBoxContainer.new()
	gold_ui.name = "UIGoldP1"
	var gold_label = TestStyle.label("46",50)
	gold_label.name = "GoldLabel"
	gold_label.get_font("font").extra_spacing_top = 10
	gold_label.get_font("font").outline_size = 3
	gold_ui.add_child(gold_label)
	add_child(gold_ui)
	add_child(meter)
	meter._add(groups[0].data,groups[0].members)
	var meter_entry = meter._entries[0]
	check(meter_entry.label.get_font("font").size,40,"damage returns to previous smaller font")
	check(gold_label.get_font("font").size,50,"damage font cannot change money font")
	var meter_panel = meter_entry.panel
	check(meter_panel.rect_min_size,Vector2(40,40),"weapon icon returns to original size")
	check(meter_entry.row.get_child(0).rect_min_size,Vector2(64,40),"icon column preserves width without extra vertical padding")
	check(meter_panel.size_flags_vertical,Control.SIZE_SHRINK_CENTER,"weapon icon vertically centered in damage row")
	check(meter_entry.row.get_constant("separation"),4,"damage moves left to money text column")
	meter_panel.rect_size = Vector2(40,40)
	check(meter_panel.get_node("Count").visible,false,"native large count stays hidden")
	var count_clip = meter_panel.get_node_or_null("DcWeaponCount")
	check(count_clip != null,true,"weapon count uses separate clipped area")
	if count_clip != null:
		var count_label = count_clip.get_child(0)
		check(count_label.text,"2","weapon count has no multiplier prefix")
		check(count_label.get_font("font").size,28,"weapon count slightly smaller")
		check(count_label.margin_bottom,2.0,"weapon count lowered slightly within clipping region")
		check(count_clip.margin_bottom,0.0,"weapon count lowered to inside bottom edge")
		check(count_clip.rect_clip_content,true,"weapon count cannot paint outside icon")
		check(meter_panel.get_rect().encloses(count_clip.get_rect()),true,"count region stays inside icon")
	meter.refresh()
	check(meter_entry.label.text,"4","main damage digits remain separate from unit")
	check(meter_entry.suffix.text,"k","compact unit displayed separately")
	check(meter_entry.suffix.modulate,Color(1,1,1,0.55),"main damage unit is muted")
	check(meter_entry.delta_box.visible,false,"new weapon has no invented comparison")
	meter.refresh(5.0)
	check(meter_entry.delta_box.visible,false,"last seconds do not invent missing previous-wave data")
	meter_entry.previous = 3000.0
	meter.refresh(60.0)
	check(meter_entry.delta_box.visible,true,"improvement visible throughout wave")
	check(meter_entry.difference.digits.text,"+1","positive damage difference")
	check(meter_entry.difference.digits.modulate,Color("00ff00"),"positive difference is green")
	check(meter_entry.difference.suffix.modulate,meter_entry.suffix.modulate,"difference unit uses muted color")
	check(meter_entry.delta_box.get_child(0).modulate,meter_entry.suffix.modulate,"opening parenthesis uses muted color")
	check(meter_entry.delta_box.get_child(2).modulate,meter_entry.suffix.modulate,"closing parenthesis uses muted color")
	meter_entry.previous = 5000.0
	meter.refresh(5.01)
	check(meter_entry.delta_box.visible,false,"lower damage hidden before final five seconds")
	meter.refresh(5.0)
	check(meter_entry.delta_box.visible,true,"lower damage visible at exact five-second boundary")
	check(meter_entry.difference.digits.text,"−1","negative damage difference")
	check(meter_entry.difference.digits.modulate,Color("ff0000"),"negative difference is red")
	meter.refresh(0.0)
	check(meter_entry.delta_box.visible,true,"final damage difference remains visible at wave end")
	meter_entry.previous = 4000.0
	meter.refresh(30.0)
	check(meter_entry.delta_box.visible,false,"equal damage hidden before final seconds")
	meter.refresh(4.0)
	check(meter_entry.delta_box.visible,true,"equal damage visible in final seconds")
	check(meter_entry.difference.digits.text,"0","unchanged damage displays zero")
	check(meter_entry.difference.digits.modulate,meter_entry.suffix.modulate,"zero difference is neutral")
	meter_entry.previous = 3000.0
	meter.refresh(30.0)
	NumberSettings.set_value("short_numbers",false)
	meter._dc_refresh_short_numbers()
	check(meter_entry.label.text,"4,000","weapon meter restores native full numbers")
	check(meter_entry.suffix.text,"","weapon meter removes compact units when disabled")
	check(meter_entry.difference.digits.text,"+1,000","damage difference restores full numbers")
	check(meter_entry.delta_box.visible,true,"number toggle preserves improvement visibility")
	meter_entry.previous = 5000.0
	meter.refresh(30.0)
	NumberSettings.set_value("short_numbers",true)
	meter._dc_refresh_short_numbers()
	check(meter_entry.label.text,"4","weapon meter reenables compact digits")
	check(meter_entry.suffix.text,"k","weapon meter reenables compact units")
	check(meter_entry.delta_box.visible,false,"number toggle preserves final-seconds gating")
	meter.free()
	gold_ui.free()
	var character = load("res://character.gd").new()
	character.my_id = "character_test"
	character.name = "Персонаж"
	var interval = load("res://interval.gd").new()
	interval.key = "stat_luck"
	interval.key_hash = Keys.generate_hash(interval.key)
	interval.value = 1
	character.effects = [interval]
	var coin_link = load("res://link.gd").new()
	coin_link.key = "stat_luck"
	coin_link.key_hash = Keys.generate_hash(coin_link.key)
	coin_link.value = 2
	var coin = object("item_lucky_coin", [coin_link])
	coin.name = "Счастливая монетка"
	var pearl_link = load("res://link.gd").new()
	pearl_link.key = "stat_percent_damage"
	pearl_link.key_hash = Keys.generate_hash(pearl_link.key)
	pearl_link.stat_scaled = "stat_luck"
	pearl_link.nb_stat_scaled = 10
	pearl_link.perm_stats_only = true
	pearl_link.value = 1
	var pearl = object("item_pearl", [pearl_link])
	pearl.name = "Жемчужина"
	var weapon = WeaponData.new()
	weapon.my_id = "weapon_gun"
	weapon.stats = load("res://stats.gd").new()
	var effects = {}
	for pair in [["stat_max_hp",30],["stat_luck",20],["stat_crit_chance",10],["weapon_slot",6]]:
		effects[Keys.generate_hash(pair[0])] = pair[1]
	effects[Keys.generate_hash("stat_links")] = [[Keys.generate_hash("stat_luck"),2,Keys.generate_hash("stat_crit_chance"),1,false],
		[Keys.generate_hash("stat_percent_damage"),1,Keys.generate_hash("stat_luck"),10,true]]
	RunData.players_data = [{"current_character":character,"current_level":5,"gold":80,"items":[character,coin,pearl],
		"weapons":[weapon],"effects":effects,"active_set_effects":[],"unique_effects":[],"additional_weapon_effects":[],
		"tier_iv_weapon_effects":[],"tier_i_weapon_effects":[],"banned_items":[]}]
	RunData.players_data[0].weapons = [first_weapon,second_weapon,other_weapon]
	var battle = load(DIR+"core/combat_log.gd").new()
	battle.finish(60)
	check(battle.weapon_damage[0]["weapon_test"],4000.0,"finished wave records grouped weapon damage")
	first_weapon.dmg_dealt_last_wave = 0
	check(battle.weapon_damage[0]["weapon_test"],4000.0,"weapon reset cannot change completed snapshot")
	RunData.set_meta("dc_combat_history",{RunData.current_wave-1:battle})
	var comparison_meter = load(DIR+"ui/damage_meter.gd").new(0)
	check(comparison_meter._previous_damage().get("weapon_test"),4000.0,"comparison uses immediately preceding wave")
	battle.weapon_damage[1]["weapon_test"] = 70.0
	var other_meter = load(DIR+"ui/damage_meter.gd").new(1)
	check(other_meter._previous_damage().get("weapon_test"),70.0,"comparison is isolated per player")
	var saved_wave = RunData.current_wave
	RunData.current_wave = 1
	check(comparison_meter._previous_damage().empty(),true,"new run has no previous-wave comparison")
	RunData.current_wave = saved_wave
	battle.duration = 0
	check(comparison_meter._previous_damage().empty(),true,"unfinished wave is not a baseline")
	battle.duration = 60
	RunData.set_meta("dc_combat_history",{RunData.current_wave-2:battle})
	check(comparison_meter._previous_damage().empty(),true,"older wave is not mistaken for previous wave")
	RunData.remove_meta("dc_combat_history")
	RunData.players_data[0].weapons = [weapon]
	comparison_meter.free()
	other_meter.free()
	battle.free()
	ItemService._tiers_data = [[[],[],[],[],[],0,1.0,0.0,1.0],[[],[],[],[],[],0,0.0,0.0,0.0],
		[[],[],[],[],[],0,0.0,0.0,0.0],[[],[],[],[],[],0,0.0,0.0,0.0]]
	var crit = load("res://upgrade.gd").new()
	crit.my_id = "upgrade_crit"
	crit.effects = [scalar("stat_crit_chance",5)]
	var ranged = object("item_ranged",[scalar("stat_ranged_damage",2)])
	ItemService.pools = {1:[ranged],2:[weapon],4:[crit]}
	var Catalog = load(DIR+"core/choice_catalog.gd")
	var catalog = Catalog.new()
	var captured = catalog.capture(0)
	check(captured.intervals.size(),1,"character intervals captured once")
	check(captured.link_sources.size(),2,"link provenance captured")
	check(captured.items.size(),3,"inventory includes character once")
	var calibrated_context = {"mode":"shop","calibration":{"ranged":0.2}}
	var pool = catalog.reroll_pool(captured,calibrated_context,{"available":true,"price":4,"draws":4,"excluded":[]})
	for entry in pool.pool:
		if entry.item.kind == "weapon":
			check(entry.item.get("calibration",1.0),0.2,"reroll weapons use same calibration as visible offers")
	var Preview = load(DIR+"core/stat_preview.gd")
	var hero_card = object("character_test",[scalar("stat_max_hp",20)])
	check(Preview.totals(hero_card,0,false).empty(),true,"character description is not a purchase preview")
	var difficulty_card = object("difficulty_test",[])
	check(Preview.totals(difficulty_card,0,false).empty(),true,"difficulty description is not a purchase preview")
	RunData.players_data[0].current_character = null
	check(Preview.totals(crit,0,false).empty(),true,"unselected character cannot produce build totals")
	RunData.players_data[0].current_character = character
	var snapshot = str([effects,RunData.players_data[0].gold,weapon.stats.damage,weapon.effects])
	var totals = Preview.totals(crit,0,false)
	var modified = scalar("stat_max_hp",3)
	modified.applied_override = 6
	check(Preview.totals(object("modified",[modified]),0,false)[Keys.stat_max_hp_hash],36.0,"native applied effect value respected")
	check(totals[Keys.stat_crit_chance_hash],15.0,"direct crit total")
	check(totals.related.rows.size(),1,"related luck row")
	check(totals.related.rows[0].delta,10.0,"coin gives ten luck")
	check(totals.related.notes.size(),1,"pearl permanent-only boundary")
	var description = Description.new()
	add_child(description)
	Preview.append_related(description,totals,true)
	check(description.texts().find("Счастливая монетка")>=0,true,"related source rendered")
	check(description.texts().find("Жемчужина")>=0,true,"blocked chain rendered")
	var count = description.effects.get_child_count()
	Preview.append_related(description,totals,true)
	check(description.effects.get_child_count(),count,"related preview does not duplicate")
	var owned = Preview.totals(crit,0,true)
	check(owned[Keys.stat_crit_chance_hash],10.0,"owned item not reapplied")
	var Advisor = load(DIR+"core/advisor.gd")
	var advisor = Advisor.new()
	seed(3181)
	var expected_random = randf()
	seed(3181)
	var advice = advisor.analyze([ranged],[5],0,{"mode":"shop","available":false})
	check(advice.cards.size(),1,"shop analysis result")
	check(advice.cards[0].has("decision"),true,"shop decision")
	check(randf(),expected_random,"adapter does not consume RNG")
	check(str([effects,RunData.players_data[0].gold,weapon.stats.damage,weapon.effects]),snapshot,"game objects unchanged")
	var Settings = load(DIR+"core/settings.gd")
	Settings.set_value("advice",true)
	var shop = load("res://shop.gd").new()
	add_child(shop)
	var container = Fixture.new()
	var shop_card = card(ranged,"ItemDescription")
	container._shop_items = [shop_card]
	shop.container = container
	var overlay = load(DIR+"core/shop_overlay.gd").new(shop,0)
	overlay.refresh()
	check(shop_card.get_node("%ItemDescription").texts().length()>0,true,"shop advice rendered")
	Settings.set_value("advice",false)
	overlay.refresh()
	check(shop_card.get_node("%ItemDescription").effects.get_child_count(),1,"shop advice clears")
	Settings.set_value("advice",true)
	var main = load(DIR+"extensions/main.gd").new()
	main._dc_advisor = advisor
	main._dc_settings = Settings
	var upgrades = Fixture.new()
	var upgrade_card = card(crit,"UpgradeDescription")
	var other_card = card(ranged,"UpgradeDescription")
	upgrades.uis = [upgrade_card,other_card]
	add_child(upgrades)
	Utils.focused_control = upgrade_card.button
	main._dc_advise_container(upgrades)
	check(upgrade_card.get_node("%UpgradeDescription").texts(),"","upgrade advice removed from card")
	var upgrade_popup = main._dc_upgrade_popups[upgrades.get_instance_id()]
	upgrade_popup.refresh()
	check(upgrade_popup._panel.visible,true,"focused upgrade shows popup")
	check(upgrade_popup._current_card,upgrade_card,"popup follows first focus")
	check(upgrade_popup._content.get_child_count()>0,true,"popup renders recommendation")
	check(upgrade_popup._panel.mouse_filter,Control.MOUSE_FILTER_IGNORE,"popup does not intercept mouse")
	Utils.focused_control = other_card.button
	upgrade_popup.refresh()
	check(upgrade_popup._current_card,other_card,"popup follows changed focus without recalculating")
	Utils.focused_control = upgrades._reroll_button
	upgrade_popup.refresh()
	check(upgrade_popup._panel.visible,false,"reroll focus hides popup")
	Utils.focused_control = upgrade_card.button
	upgrades._upgrades_container.hide()
	upgrade_popup.refresh()
	check(upgrade_popup._panel.visible,false,"hidden upgrade screen hides popup")
	upgrades._upgrades_container.show()
	upgrade_card.upgrade_data = ranged
	upgrade_popup.refresh()
	check(upgrade_popup._panel.visible,false,"replaced upgrade cannot show stale advice")
	main._dc_advise_container(upgrades)
	upgrade_popup.refresh()
	check(upgrade_popup._panel.visible,true,"new analysis refreshes popup")
	var Popup = upgrade_popup.get_script()
	var bounds = Rect2(0,0,1000,700)
	check(Popup.position_for(Rect2(100,100,200,300),Vector2(250,150),bounds).x>300,true,"popup prefers right side")
	check(Popup.position_for(Rect2(800,600,180,80),Vector2(250,150),bounds).x<800,true,"popup flips at right edge")
	check(Popup.position_for(Rect2(800,600,180,80),Vector2(250,150),bounds).y<=550,true,"popup stays above bottom edge")
	Settings.set_value("advice",false)
	main._dc_advise_container(upgrades)
	check(upgrade_card.get_node("%UpgradeDescription").effects.get_child_count(),1,"upgrade advice clears")
	check(upgrade_popup._panel.visible,false,"disabled analyzer hides popup")
	Settings.set_value("advice",true)
	RunData.is_coop_run = true
	main._dc_advise_container(upgrades)
	check(upgrade_card.get_node("%UpgradeDescription").texts().length()>0,true,"coop keeps existing inline advice")
	check(upgrade_popup._panel.visible,false,"coop cannot create overlapping popups")
	RunData.is_coop_run = false
	var popup = load(DIR+"extensions/ui/menus/shop/item_popup.gd").new()
	var panel = Fixture.new()
	panel._item_description = Description.new()
	popup._panel = panel
	popup._item_data = weapon
	popup._discard_button = Button.new()
	popup._dc_advisor = advisor
	popup._dc_owned = true
	popup._dc_refresh_advice()
	check(panel._item_description.texts().length()>0,true,"sale and replacement advice rendered")
	Settings.set_value("advice",false)
	popup._dc_refresh_advice()
	check(panel._item_description.effects.get_child_count(),1,"sale advice clears")
	check(str([effects,RunData.players_data[0].gold,weapon.stats.damage,weapon.effects]),snapshot,"all integrations preserve actual state")
	main.free()
	upgrades.free()
	container.free()
	popup._discard_button.free()
	popup.free()
	panel._item_description.free()
	panel.free()
	print("Game contract: ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)
