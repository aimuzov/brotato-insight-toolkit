extends Reference

# Повторяет логику WaveManager + EntitySpawner, но вместо спавна считает
# ожидаемое HP врагов. Случайности (min..max, spawn_chance) заменены матожиданием.

var _stats_cache = {}
var _hp_factor = null


# Статы игрока меняются в магазине, а множитель HP от них зависит
func reset_cache() -> void:
	_hp_factor = null


# Нормализованная группа: словарь с полями WaveGroupData и весом
# (weight < 1 у вариантов conditional_groups_data, из которых игра берёт один)
func group_from_data(group_data: Resource, weight: float = 1.0, units_override = null) -> Dictionary:
	var units = units_from(units_override if units_override != null else group_data.wave_units_data)
	return {
		"spawn_timing": group_data.spawn_timing,
		"spawn_chance": group_data.spawn_chance,
		"repeating": group_data.repeating,
		"interval": group_data.repeating_interval,
		"reduce": group_data.reduce_repeating_interval,
		"min_interval": group_data.min_repeating_interval,
		"is_boss": group_data.is_boss,
		"is_loot": group_data.is_loot,
		"is_neutral": group_data.is_neutral,
		"prevent_if_elite": group_data.prevent_if_elite,
		"prevent_if_horde": group_data.prevent_if_horde,
		"min_difficulty": group_data.min_difficulty,
		"max_difficulty": group_data.max_difficulty,
		"units": units,
		"weight": weight,
	}


func units_from(units_data: Array) -> Array:
	var units = []
	for unit_data in units_data:
		units.push_back({
			"type": unit_data.type,
			"scene": unit_data.unit_scene,
			"min": unit_data.min_number,
			"max": unit_data.max_number,
			"chance": unit_data.spawn_chance,
		})
	return units


func boss_unit(scene: PackedScene) -> WaveUnitData:
	var unit = WaveUnitData.new()
	unit.type = EntityType.BOSS
	unit.unit_scene = scene
	return unit


func elite_scene(elite_id_hash: int) -> PackedScene:
	for elite in ItemService.elites:
		if elite.my_id_hash == elite_id_hash:
			return elite.scene
	return null


func boss_scene(boss_id: String) -> PackedScene:
	var boss = ItemService.get_element(ItemService.bosses, Keys.generate_hash(boss_id))
	return boss.scene if boss != null else null


# Группы следующей волны так, как их соберёт WaveManager.init()
func build_wave_groups(wave: int) -> Dictionary:
	var zone = ZoneService.get_zone_data(RunData.current_zone)
	var wave_data
	var mapped = RunData.get("time_shifter_wave_mapping")
	var index = int(mapped.get(wave, wave)) if mapped is Dictionary else wave
	if index <= zone.waves_data.size():
		wave_data = zone.waves_data[index - 1]
	else:
		var repeated = (index - 1) % zone.waves_data.size()
		if repeated < 10:
			repeated = min(repeated + 10, zone.waves_data.size() - 1)
		wave_data = zone.waves_data[repeated].duplicate()
		wave_data.wave_duration = 60

	var groups = []
	var elite_units = []

	for group_data in wave_data.groups_data:
		if not group_data.is_boss:
			groups.push_back(group_from_data(group_data))
			continue

		var units = []
		if wave == RunData.nb_of_waves:
			for boss_id in RunData.bosses_spawn:
				units.push_back(boss_unit(boss_scene(boss_id)))
		elif wave > RunData.nb_of_waves:
			for boss_id in RunData.bosses_spawn:
				units.push_back(boss_unit(boss_scene(boss_id)))
			for elite_id in RunData.get_additional_elites_endless():
				elite_units.push_back(boss_unit(elite_scene(elite_id)))
		groups.push_back(group_from_data(group_data, 1.0, units))

	for group_data in zone.groups_data_in_all_waves:
		groups.push_back(group_from_data(group_data))

	for group_array in wave_data.conditional_groups_data:
		for group_data in group_array:
			groups.push_back(group_from_data(group_data, 1.0 / group_array.size()))

	var flags = elite_flags(wave)
	for elite_spawn in RunData.elites_spawn:
		if (elite_spawn[0] as int) != wave:
			continue
		if elite_spawn[1] == EliteType.ELITE:
			elite_units.push_back(boss_unit(elite_scene(elite_spawn[2])))
		elif elite_spawn[1] == EliteType.HORDE:
			for group_data in zone.horde_groups:
				if wave >= group_data.min_wave and wave <= group_data.max_wave:
					groups.push_back(group_from_data(group_data))
		break

	if elite_units.size() > 0:
		# Шаблон elite_group из main.tscn: спавн на 1-й секунде, без повторов
		groups.push_back({
			"spawn_timing": 1, "spawn_chance": 1.0, "repeating": -1, "interval": 3, "reduce": 0,
			"min_interval": 1, "is_boss": true, "is_loot": false, "is_neutral": false,
			"prevent_if_elite": false, "prevent_if_horde": false,
			"min_difficulty": 0, "max_difficulty": 9999, "weight": 1.0,
			"units": units_from(elite_units),
		})

	return {
		"groups": groups,
		"duration": wave_data.wave_duration,
		"is_elite": flags.is_elite,
		"is_horde": flags.is_horde,
		"partial": index > zone.waves_data.size(),
	}


func elite_flags(wave: int) -> Dictionary:
	var result = {"is_elite": false, "is_horde": false}
	for elite_spawn in RunData.elites_spawn:
		if (elite_spawn[0] as int) == wave:
			if elite_spawn[1] == EliteType.ELITE:
				result.is_elite = true
			elif elite_spawn[1] == EliteType.HORDE:
				result.is_horde = true
	return result


func simulate(pending: Array, duration: float, wave: int, flags: Dictionary) -> Dictionary:
	var result = {"total_hp": 0.0, "enemies": 0.0, "boss_hp": 0.0, "materials": 0.0}
	var time_left = duration

	for group in pending:
		if group.prevent_if_horde and flags.is_horde:
			continue
		if group.prevent_if_elite and flags.is_elite:
			continue
		if RunData.current_difficulty < group.min_difficulty or RunData.current_difficulty > group.max_difficulty:
			continue

		var trigger = time_left if group.is_boss else min(time_left, duration - group.spawn_timing)
		# WaveManager проверяет группы раз в секунду, последний раз около time_left = 1
		if trigger < 1.0:
			continue

		_add_emission(result, group, group.spawn_chance * group.weight, wave)

		if group.repeating > 0:
			var next_repeat = duration - group.spawn_timing - group.interval
			_simulate_repeats(result, group, group.repeating, group.interval, next_repeat, time_left, wave)


	return result


func _simulate_repeats(result: Dictionary, group: Dictionary, repeating: int, interval: float, next_repeat: float, time_left: float, wave: int) -> void:
	while repeating > 0 and next_repeat >= 1.0:
		if next_repeat <= time_left:
			_add_emission(result, group, group.weight, wave)
		repeating -= 1
		interval = max(group.min_interval, interval - group.reduce)
		next_repeat -= interval


func _add_emission(result: Dictionary, group: Dictionary, mult: float, wave: int) -> void:
	if group.is_loot or group.is_neutral or mult <= 0.0:
		return

	var coop_factor = (RunData.get_player_count() - 1) * CoopService.additional_enemies_per_coop_player
	var enemy_modifier = RunData.sum_all_player_effects(Keys.number_of_enemies_hash) / 100.0

	for unit in group.units:
		if unit.scene == null:
			continue
		var number = (unit.min + unit.max) / 2.0
		if unit.type == EntityType.ENEMY:
			number += number * coop_factor
			number = max(1.0, number + number * enemy_modifier)
		elif unit.type != EntityType.BOSS:
			continue

		var count = number * unit.chance * mult
		var is_boss = group.is_boss or unit.type == EntityType.BOSS
		var hp = count * unit_hp(unit.scene, wave, is_boss)
		result.total_hp += hp
		result.enemies += count
		if is_boss:
			result.boss_hp += hp
		var stats = scene_stats(unit.scene)
		if stats != null:
			result.materials += count * stats.value


# HP врага так, как его посчитают Unit.reset_health_stat() и Boss.init()
func unit_hp(scene: PackedScene, wave: int, is_boss: bool) -> float:
	var stats = scene_stats(scene)
	if stats == null:
		return 0.0

	var hp = round(stats.get_base_health(wave) * hp_factor(wave))
	if is_boss:
		var double_boss = RunData.sum_all_player_effects(Keys.double_boss_hash) > 0
		if wave <= 8:
			hp = round(hp * 0.5)
		elif (double_boss and wave == RunData.nb_of_waves) or wave <= 12:
			hp = round(hp * 0.75)
		elif wave == RunData.nb_of_waves and RunData.current_difficulty <= 0 and RunData.current_zone != 0:
			hp = round(hp * 0.9)
	return hp


# Копия EntityService.get_final_enemy_health() с явным номером волны:
# кеш игры считается для текущей волны, а прогноз нужен для следующей
func hp_factor(wave: int) -> float:
	if _hp_factor != null and _hp_factor[0] == wave:
		return _hp_factor[1]

	var effects_factor = max(0.01, 1.0 + Utils.sum_all_player_stats(Keys.enemy_health_hash) / 100.0)
	var danger_factor = max(0.01, 1.0 + RunData.get_player_effect(Keys.danger_enemy_health_hash, 0) / 100.0)
	var coop_factor = max(0.01, 1.0 + ((RunData.get_player_count() - 1) * CoopService.additional_enemy_health_per_coop_player))
	var accessibility_factor = RunData.current_run_accessibility_settings.health

	var curse_factor = 0.0
	if Keys.stat_curse_hash in RunData.get_player_effects(0):
		var curse_stat = Utils.average_all_player_stats(Keys.stat_curse_hash)
		if curse_stat >= 0:
			curse_factor = sqrt(curse_stat) / 10.0

	var endless_factor = max(0.01, 1.0 + (RunData.get_endless_factor(wave) * 2.25) * (1.0 + curse_factor))
	var factor = danger_factor * accessibility_factor * coop_factor * effects_factor * endless_factor
	_hp_factor = [wave, factor]
	return factor


# Stats врага читаем из SceneState без инстанцирования сцены
func scene_stats(scene: PackedScene) -> Resource:
	var key = scene.resource_path
	if _stats_cache.has(key):
		return _stats_cache[key]

	var result = null
	var current = scene
	while current != null and result == null:
		var state = current.get_state()
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == "stats":
				result = state.get_node_property_value(0, i)
				break
		current = state.get_node_instance(0) if result == null else null

	if result == null:
		var instance = scene.instance()
		result = instance.stats
		instance.free()

	_stats_cache[key] = result
	return result
