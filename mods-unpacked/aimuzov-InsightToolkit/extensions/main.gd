extends "res://main.gd"

const DC_DIR = "res://mods-unpacked/aimuzov-InsightToolkit/"
const DcStyle = preload("res://mods-unpacked/aimuzov-InsightToolkit/ui/style.gd")
const DC_UPDATE_INTERVAL = 0.5

var _dc_log
var _dc_advisor
var _dc_upgrades_keys = {}
var _dc_settings
var _dc_meters = []


func _ready() -> void:
	_dc_setup()


func _dc_setup() -> void:
	for index in RunData.get_player_count():
		preload("res://mods-unpacked/aimuzov-InsightToolkit/ui/tumor_notification.gd").remember(index)
	_dc_settings = load(DC_DIR + "core/settings.gd")
	add_child(load(DC_DIR + "core/wave_speed.gd").new(_wave_timer))
	_dc_setup_damage_meter()
	_dc_setup_range_rings()
	_dc_setup_combat_log()
	_dc_advisor = load(DC_DIR + "core/advisor.gd").new()
	add_to_group("dc_item_advice")
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.pause_mode = PAUSE_MODE_PROCESS
	timer.connect("timeout", self, "_dc_advise_upgrades")
	add_child(timer)
	timer.start()


func _dc_refresh_advice() -> void:
	_dc_upgrades_keys.clear()
	_dc_advise_upgrades()


func _dc_setup_damage_meter() -> void:
	var DamageMeter = load(DC_DIR + "ui/damage_meter.gd")
	for player_index in _players.size():
		var life_container = get_node_or_null("UI/HUD/LifeContainerP%d" % (player_index + 1))
		if life_container == null:
			continue
		var meter = DamageMeter.new(player_index)
		life_container.add_child(meter)
		# Нижние игроки в коопе на четверых: список над полосками, а не под ними
		if player_index > 1:
			life_container.move_child(meter, 0)
		meter.build()
		_dc_meters.push_back(meter)

	var timer = Timer.new()
	timer.wait_time = DC_UPDATE_INTERVAL
	var _e = timer.connect("timeout", self, "_dc_update_damage_meter")
	add_child(timer)
	timer.start()
	_dc_update_damage_meter()


func _dc_setup_range_rings() -> void:
	var RangeRings = load(DC_DIR + "ui/range_rings.gd")
	for player in _players:
		player.add_child(RangeRings.new(player))


func _dc_update_damage_meter() -> void:
	if not is_instance_valid(_wave_timer):
		return
	if _wave_timer.is_stopped() or _wave_timer.time_left <= 0:
		if not has_meta("dc_meter_hiding"):
			set_meta("dc_meter_hiding", true)
			get_tree().create_timer(2.0).connect("timeout", self, "_dc_hide_damage_meter")
		return
	var shown = _dc_settings.enabled("damage_meter")
	for meter in _dc_meters:
		meter.visible = shown
		if shown:
			meter.refresh(_wave_timer.time_left)


func _dc_hide_damage_meter() -> void:
	for meter in _dc_meters:
		if is_instance_valid(meter):
			meter.hide()


func _dc_setup_combat_log() -> void:
	_dc_log = load(DC_DIR + "core/combat_log.gd").new()
	if RunData.current_wave == 1 or not RunData.has_meta("dc_combat_history"):
		RunData.set_meta("dc_combat_history", {})
	RunData.get_meta("dc_combat_history")[RunData.current_wave] = _dc_log
	var _e1 = _entity_spawner.connect("enemy_spawned", self, "_dc_on_enemy_spawned")
	var _e2 = _entity_spawner.connect("enemy_respawned", self, "_dc_on_enemy_spawned")
	for player in _players:
		_dc_log.track_player(player, self)
	_wave_timer.connect("timeout", self, "_dc_finish_choice_metrics")
	for index in _players.size():
		if Engine.has_meta("dc_choice_shop_%d" % index):
			Engine.remove_meta("dc_choice_shop_%d" % index)


func on_gold_picked_up(gold: Node, player_index: int) -> void:
	if _dc_log != null and not gold.already_picked_up and player_index >= 0 and player_index < _dc_log.metrics.size():
		_dc_log.metrics[player_index].gold_pickups += 1
	.on_gold_picked_up(gold, player_index)


func _dc_finish_choice_metrics() -> void:
	call_deferred("_dc_save_choice_metrics")


func _dc_save_choice_metrics() -> void:
	_dc_log.finish(_wave_timer.wait_time)
	for meter in _dc_meters:
		if is_instance_valid(meter):
			meter.finish_wave(_dc_log)


func _dc_on_player_health_updated(player: Node, health: int, _max_health: int) -> void:
	_dc_log.on_player_health_updated(player, health)


func _dc_on_enemy_spawned(enemy: Node) -> void:
	_dc_log.track_enemy(enemy, self)


func _dc_on_enemy_health_updated(unit: Node, current_health: int, _max_health: int) -> void:
	_dc_log.on_enemy_health_updated(unit, current_health)


func _dc_on_enemy_took_damage(unit, value, _knockback, _is_crit, _is_dodge, _is_protected, _armor, args, _hit_type, _one_shot) -> void:
	_dc_log.on_enemy_took_damage(unit, value, args)


func _dc_on_enemy_died(unit: Node, args) -> void:
	_dc_log.on_enemy_died(unit, args)


func _dc_on_player_took_damage(player, value, _knockback, _is_crit, _is_dodge, _is_protected, _armor, args, _hit_type, _one_shot) -> void:
	_dc_log.on_player_took_damage(player, value, args)


func _dc_advise_upgrades() -> void:
	var containers = []
	for ui in [_upgrades_ui, _coop_upgrades_ui]:
		if ui == null or not ui.visible:
			continue
		for prop in ["_player_container1", "_player_container2", "_player_container3", "_player_container4"]:
			var container = ui.get(prop)
			if container != null and container.visible:
				if container._upgrades_container.visible:
					containers.push_back(container)
				elif container._items_container.visible:
					_dc_advise_reward(container)

	for container in containers:
		_dc_advise_container(container)


func _dc_advise_container(container: Node) -> void:
	var player_index = container.player_index
	var uis = []
	var enabled = _dc_settings.enabled("advice")
	var key = str(enabled) + str(container._reroll_button.visible) + str(RunData.is_coop_run) + str(RunData.get_player_gold(player_index)) + ":" + str(container._reroll_price)
	for upgrade_ui in container._get_upgrade_uis():
		if upgrade_ui.visible and upgrade_ui.upgrade_data != null:
			uis.push_back(upgrade_ui)
			key += str(upgrade_ui.get_instance_id()) + ":" + str(upgrade_ui.upgrade_data.get_instance_id()) + ","
			var description = upgrade_ui.get_node("%UpgradeDescription")
			key += str(description.get_meta("dc_description_version") if description.has_meta("dc_description_version") else 0)
	if key == _dc_upgrades_keys.get(container.get_instance_id(), ""):
		return
	_dc_upgrades_keys[container.get_instance_id()] = key
	if not enabled:
		for ui in container._get_upgrade_uis():
			DcStyle.mark_choice(ui, false)
		DcStyle.mark_choice(container._reroll_button, false)
		return
	var resources = []
	var prices = []
	var excluded = []
	for ui in uis:
		resources.push_back(ui.upgrade_data)
		prices.push_back(0)
		excluded.push_back(ui.upgrade_data.my_id)
	var result = _dc_advisor.analyze(resources, prices, player_index, {
		"mode": "upgrade", "level": container._level, "price": container._reroll_price,
		"draws": uis.size(), "excluded": excluded, "available": container._reroll_button.visible,
	})
	for i in uis.size():
		DcStyle.mark_choice(uis[i], result.cards[i].recommended)
	DcStyle.mark_choice(container._reroll_button, result.roll_wins)


func _dc_advise_reward(container: Node) -> void:
	var item = container._item_data
	if item == null:
		return
	var player_index = container.player_index
	var enabled = _dc_settings.enabled("advice")
	var key = "reward:" + str(container._discard_button.visible) + str(enabled) + ":" + str(item.get_instance_id())
	var description = container._item_description
	key += ":" + str(description.get_meta("dc_description_version") if description.has_meta("dc_description_version") else 0)
	if key == _dc_upgrades_keys.get(container.get_instance_id(), ""):
		return
	_dc_upgrades_keys[container.get_instance_id()] = key
	_dc_advisor.clear_description(description)
	DcStyle.mark_choice(container._discard_button, false)
	if not enabled:
		return
	var result = _dc_advisor.evaluate_reward(item, player_index, container._discard_button.visible)
	if result.get("recommend_discard", false):
		DcStyle.mark_choice(container._discard_button, true)
	else:
		_dc_advisor.write_to_description(description, result)
