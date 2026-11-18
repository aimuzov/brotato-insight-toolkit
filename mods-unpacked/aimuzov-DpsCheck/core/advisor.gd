extends Reference

const Catalog = preload("choice_catalog.gd")
const Planner = preload("choice_planner.gd")
const State = preload("choice_state.gd")
const Model = preload("choice_model.gd")
const LINE_PREFIX = "DcAdvice"
const BEST_COLOR = "ffd75e"
const MUTED_COLOR = "9a9a9a"

var _catalog
var _planner
var _forecast


func _init(_calc = null) -> void:
	_catalog = Catalog.new()
	_planner = Planner.new()
	_forecast = load("res://mods-unpacked/aimuzov-DpsCheck/core/wave_forecast.gd").new()


func context(player_index: int = 0) -> Dictionary:
	var wave = RunData.current_wave + 1
	_forecast.reset_cache()
	var info = _forecast.build_wave_groups(wave)
	var threat = _forecast.simulate(info.groups, info.duration, wave, info)
	var seconds = max(1.0, info.duration)
	var result = {
		"duration": seconds, "required_dps": threat.total_hp / seconds / max(1, RunData.get_player_count()),
		"density": clamp(threat.enemies / seconds * 3.0, 0.5, 12.0),
		"boss_fraction": threat.boss_hp / max(1.0, threat.total_hp),
		"income": max(25.0, threat.materials * 0.65 / max(1, RunData.get_player_count())),
		"horizon": 3 if RunData.is_endless_run else int(clamp(RunData.nb_of_waves - wave, 0, 3)),
		"hit_rate": 0.15, "mean_hit": 2.0 + wave * 0.6, "max_hit": 4.0 + wave,
		"kill_rate": max(0.2, threat.enemies / seconds / max(1, RunData.get_player_count())),
		"pickup_rate": 1.0, "confidence": 0.65, "partial_forecast": info.get("partial", false),
	}
	var history = RunData.get_meta("dc_combat_history") if RunData.has_meta("dc_combat_history") else {}
	var keys = history.keys()
	keys.sort()
	keys.invert()
	for previous in keys:
		var log_data = history[previous]
		if log_data.duration <= 0.0:
			continue
		var record = log_data.metrics[player_index]
		result.hit_rate = record.hits / log_data.duration / max(0.1, 1.0 - record.get("dodge", 0.0))
		if record.hits > 0:
			result.mean_hit = max(result.mean_hit * 0.5, record.taken / record.hits / max(0.05, record.get("armor", 1.0)))
			result.max_hit = max(result.max_hit, record.max_hit / max(0.05, record.get("armor", 1.0)))
		result.kill_rate = record.kills / log_data.duration
		result.pickup_rate = max(0.1, record.income / log_data.duration)
		result.income = max(15.0, result.income * 0.5 + record.income * 0.5)
		result.confidence = 0.8
		result["observed_duration"] = log_data.duration
		break
	return result


func analyze(resources: Array, prices: Array, player_index: int, options: Dictionary = {}) -> Dictionary:
	var data = _catalog.capture(player_index)
	var environment = context(player_index)
	environment["base_enemy_count"] = float(data.effects.get("number_of_enemies", 0.0))
	environment["base_enemy_damage"] = float(data.effects.get("enemy_damage", 0.0))
	environment["mode"] = options.get("mode", "shop")
	environment["currency_kind"] = data.currency_kind
	calibrate(data, environment, player_index)
	var definitions = []
	for index in resources.size():
		var definition = _catalog.item(resources[index])
		definition.price = prices[index]
		Catalog.apply_profile(definition, environment)
		definitions.push_back(definition)
	data.sets = _catalog._sets.duplicate(true)
	var pool = _catalog.reroll_pool(data, environment, options)
	var result = _planner.plan(data, definitions, environment, pool)
	for card in result.cards:
		if card.get("ok", false):
			card["currency_kind"] = data.currency_kind
			card["forecast_partial"] = environment.partial_forecast
			if result.roll_wins:
				card.reasons.push_back("Реролл: ожидаемая выгода %s материалов" % Planner.signed(result.reroll.expected))
	return result


func calibrate(data: Dictionary, environment: Dictionary, player_index: int) -> void:
	if not environment.has("observed_duration"):
		return
	var state = State.new(data)
	var owned = RunData.get_player_weapons(player_index)
	var profiles = {}
	for index in min(data.weapons.size(), owned.size()):
		var observed = owned[index].dmg_dealt_last_wave / max(1.0, environment.observed_duration)
		if observed <= 0:
			continue
		var predicted = Model.weapon_output(state, data.weapons[index], environment).dps
		data.weapons[index]["calibration"] = clamp(observed / max(0.1, predicted), 0.2, 3.0)
		for key in [data.weapons[index].family, "ranged" if data.weapons[index].stats.ranged else "melee"]:
			if not profiles.has(key):
				profiles[key] = [0.0, 0]
			profiles[key][0] += data.weapons[index].calibration
			profiles[key][1] += 1
	environment["calibration"] = {}
	for key in profiles:
		environment.calibration[key] = profiles[key][0] / profiles[key][1]


func evaluate_reward(resource: Resource, player_index: int, can_discard: bool) -> Dictionary:
	var data = _catalog.capture(player_index)
	var environment = context(player_index)
	environment["base_enemy_count"] = float(data.effects.get("number_of_enemies", 0.0))
	environment["base_enemy_damage"] = float(data.effects.get("enemy_damage", 0.0))
	calibrate(data, environment, player_index)
	var initial = State.new(data)
	var baseline = Model.evaluate(initial, environment)
	var definition = _catalog.item(resource)
	data.sets = _catalog._sets.duplicate(true)
	initial = State.new(data)
	var take = _planner.route(initial, [{"kind": "buy", "item": definition, "cost": 0}], baseline, environment, Planner.money_weight(data, environment))
	var recycle = ItemService.get_item_box_recycling_value(RunData.current_wave, resource.value, player_index, resource is WeaponData)
	var sold = initial.fork()
	sold.data.cash += recycle
	if sold.data.currency_kind == "gold":
		sold.data.currency = sold.data.cash
	var sell_value = Model.improvement(baseline, Model.evaluate(sold, environment), environment) + recycle * Planner.money_weight(data, environment)
	if not take.ok:
		return {"decision": "Можно разобрать: +%d материалов" % recycle if can_discard else take.reason, "confidence": "low", "reasons": [take.reason], "unknown": []}
	if take.confidence == "low":
		take["decision"] = "Проверь неучтённые эффекты перед разбором"
	elif not can_discard or take.value > sell_value + 1.0:
		take["decision"] = "Взять по расчёту"
	elif abs(take.value - sell_value) <= 1.0:
		take["decision"] = "Взять или разобрать: сопоставимая польза"
	else:
		take["decision"] = "Разобрать: +%d материалов" % recycle
	return take


func evaluate_sale(resource: Resource, player_index: int) -> Dictionary:
	var resources = []
	var prices = []
	var key = "dc_choice_shop_%d" % player_index
	if Engine.has_meta(key):
		var current = Engine.get_meta(key)
		if current.wave == RunData.current_wave and current.owner.get_ref() != null:
			for reference in current.items:
				var card = reference.get_ref()
				if card != null and card.visible and card.active and card.item_data != null:
					resources.push_back(card.item_data)
					prices.push_back(card.value)
	var plan = analyze(resources, prices, player_index, {"mode": "shop"})
	return plan.sales.get(str(resource.get_instance_id()), {"decision": "Нет данных о продаже", "confidence": "low", "reasons": [], "unknown": []})


func clear_description(description: Node) -> void:
	var effects = description.get_effects()
	for child in effects.get_children():
		if child.name.begins_with(LINE_PREFIX):
			effects.remove_child(child)
			child.queue_free()


func write_to_description(description: Node, result: Dictionary) -> void:
	clear_description(description)
	var effects = description.get_effects()
	for line in describe_lines(result):
		var effect_line = description.effect_line.instance()
		effect_line.name = LINE_PREFIX + str(effects.get_child_count())
		effects.add_child(effect_line)
		effect_line._display_special_text(line[0], line[1])
	effects.visible = effects.get_child_count() > 0


func describe_lines(result: Dictionary) -> Array:
	var lines = []
	var decision = result.get("decision", result.get("reason", "Нужна ручная проверка"))
	lines.push_back(["[color=#%s]%s[/color]" % [BEST_COLOR, decision], null])
	for reason in result.get("reasons", []).slice(0, 2):
		lines.push_back([reason, null])
	var unknown = result.get("unknown", [])
	if not unknown.empty():
		lines.push_back(["[color=#%s]Не учтено: %s[/color]" % [MUTED_COLOR, PoolStringArray(unknown.slice(0, 1)).join(", ")], null])
	elif result.get("confidence", "low") != "high":
		lines.push_back(["[color=#%s]Приближённая оценка[/color]" % MUTED_COLOR, null])
	return lines
