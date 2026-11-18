extends Reference

const State = preload("choice_state.gd")
const MAX_SAMPLES = 48
const SUPPORTED = [
	"stat_max_hp", "stat_hp_regeneration", "stat_lifesteal", "stat_percent_damage", "stat_melee_damage",
	"stat_ranged_damage", "stat_elemental_damage", "stat_engineering", "stat_attack_speed", "stat_crit_chance",
	"stat_armor", "stat_dodge", "stat_speed", "stat_range", "stat_harvesting", "stat_luck", "bonus_crit_damage",
	"hp_cap", "speed_cap", "dodge_cap", "crit_chance_cap", "curse_cap", "items_price", "weapons_price",
	"projectiles", "piercing", "bounce", "accuracy", "piercing_damage", "bounce_damage", "explosion_damage",
	"explosion_size", "burning_duration", "burning_speed", "structure_percent_damage", "structure_attack_speed",
	"structures_can_crit", "weapon_slot", "weapon_slot_upgrades", "max_weapon_tier", "min_weapon_tier",
	"no_melee_weapons", "no_ranged_weapons", "no_duplicate_weapons", "lock_current_weapons", "max_melee_weapons", "max_ranged_weapons",
	"weapon_set_bonus", "all_weapons_count_for_sets", "hp_shop", "recycling_gains", "item_box_recycling_gains",
	"xp_gain", "harvesting_growth", "enemy_health", "enemy_damage", "number_of_enemies", "knockback",
	"stat_boosted_wanted_item_tag", "effect_no_weapon_in_shop", "minimum_weapons_in_shop", "reroll_price",
]

var _player = 0
var _items = {}
var _sets = {}


func capture(player_index: int) -> Dictionary:
	_player = player_index
	_items.clear()
	_sets.clear()
	var player = RunData.players_data[player_index]
	var data = {"effects": {}, "weapons": [], "items": [], "sets": {}, "applied_sets": [], "derived": {},
		"sources": [], "unknown": [], "intervals": [], "temporary": {}, "link_sources": [], "item_gain_sources": [], "cash": RunData.get_player_gold(player_index),
		"currency": RunData.get_player_currency(player_index), "currency_kind": "gold", "wave": RunData.current_wave,
		"last_wave": RunData.nb_of_waves, "level": player.current_level,
		"character": str(player.current_character.my_id), "character_name": tr(player.current_character.name)}
	for key in player.effects:
		var name = key_name(key)
		var value = player.effects[key]
		if value is int or value is float or value is bool:
			data.effects[name] = float(value)
		elif value is Array:
			data.effects[name] = effect_array(name, value)
	if float(data.effects.get("hp_shop", 0)) > 0:
		data.currency_kind = "hp"
	for weapon in RunData.get_player_weapons(player_index):
		data.weapons.push_back(item(weapon))
	for owned in RunData.get_player_items(player_index):
		data.items.push_back(item(owned))
	for active in player.active_set_effects:
		data.applied_sets.append_array(effect(active[1]))
	for pair in [["unique", "unique_effects"], ["additional", "additional_weapon_effects"], ["tier_iv", "tier_iv_weapon_effects"], ["tier_i", "tier_i_weapon_effects"]]:
		data.derived[pair[0]] = stat_pairs(player.get(pair[1]))
	for key in TempStats.player_stats[player_index]:
		data.temporary[key_name(key)] = TempStats.player_stats[player_index][key]
	var character = item(player.current_character)
	var character_present = false
	for owned in data.items:
		character_present = character_present or owned.id == character.id
	if not character_present:
		data.sources.append_array(character.sources)
		data.unknown.append_array(character.unknown)
	for object in data.items + data.weapons + ([] if character_present else [character]):
		for definition in object.effects:
			if definition.kind == "interval":
				data.intervals.push_back(definition.duplicate(true))
			elif definition.kind == "link":
				data.link_sources.push_back({"from": definition.entry[2], "to": definition.entry[0], "name": object.name})
			elif definition.kind == "on_item_gain":
				data.item_gain_sources.push_back({"from": definition.entry[2], "to": definition.entry[0], "name": object.name})
	data.sets = _sets.duplicate(true)
	return data


func item(resource: Resource, depth: int = 0) -> Dictionary:
	var cache_key = str(resource.get_instance_id()) + ":" + str(depth)
	if _items.has(cache_key):
		return _items[cache_key].duplicate(true)
	var weapon = resource is WeaponData
	var data = {"id": resource.my_id, "uid": str(resource.get_instance_id()), "name": resource.get_name_text(), "tier": resource.tier,
		"kind": "weapon" if weapon else ("upgrade" if resource.get("upgrade_id") != null else "item"),
		"effects": [], "sources": [], "unknown": [], "sets": [], "weapon_effects": [], "value": resource.value,
		"max_nb": read(resource, "max_nb", -1), "flavor": "plain", "price": 0,
		"crate_recycle_value": ItemService.get_item_box_recycling_value(RunData.current_wave, resource.value, _player, weapon)}
	if resource.is_cursed or resource.is_meca or resource.is_mutant:
		data.flavor = "special"
		data.unknown.push_back("Проклятые и эволюционные эффекты оценены частично")
	for current in resource.effects:
		var definitions = effect(current)
		for definition in definitions:
			definition["source_name"] = data.name
		data.effects.append_array(definitions)
		for definition in definitions:
			if definition.kind == "unknown":
				data.unknown.push_back(definition.label)
			elif definition.kind == "source":
				data.sources.push_back(definition.source)
			elif definition.kind == "weapon_effect":
				data.weapon_effects.push_back(definition.effect)
	if weapon:
		data["weapon_type"] = resource.type
		data["family"] = str(read(resource, "weapon_id", resource.my_id))
		data["stats"] = stats(resource.stats)
		for set in resource.sets:
			data.sets.push_back(set.my_id)
			if not _sets.has(set.my_id):
				var levels = []
				for level in set.set_bonuses:
					var definitions = []
					for current in level:
						definitions.append_array(effect(current))
					levels.push_back(definitions)
				_sets[set.my_id] = levels
		if depth == 0 and resource.upgrades_into != null:
			data["upgrade"] = item(resource.upgrades_into, 1)
		var specific = 1.0
		for entry in RunData.get_player_effects(_player).get(Keys.generate_hash("specific_items_price"), []):
			if str(key_name(entry[0])) in resource.my_id:
				specific = entry[1]
				break
		data["sale_value"] = ItemService.get_recycling_value(RunData.current_wave, int(resource.value * specific), _player, true)
	_items[cache_key] = data.duplicate(true)
	return data


func stats(resource: Resource) -> Dictionary:
	if resource == null:
		return {}
	var ranged = resource.get("nb_projectiles") != null
	return {"damage": resource.damage, "cooldown": resource.cooldown, "accuracy": resource.accuracy,
		"crit_chance": resource.crit_chance, "crit_damage": resource.crit_damage, "range": resource.max_range,
		"lifesteal": resource.lifesteal, "attack_speed_mod": resource.attack_speed_mod, "scaling": stat_pairs(resource.scaling_stats),
		"ranged": ranged, "healing": resource.is_healing, "projectiles": read(resource, "nb_projectiles", 1),
		"piercing": read(resource, "piercing", 0), "piercing_reduction": read(resource, "piercing_dmg_reduction", 0.5),
		"bounce": read(resource, "bounce", 0), "bounce_reduction": read(resource, "bounce_dmg_reduction", 0.5),
		"return_damage": read(resource, "deal_dmg_on_return", false), "animation": read(resource, "attack_duration", 0.15),
		"additional_cooldown_every_x_shots": resource.additional_cooldown_every_x_shots,
		"additional_cooldown_multiplier": resource.additional_cooldown_multiplier, "burn": burn(resource.burning_data)}


func effect(resource: Resource) -> Array:
	var id = resource.get_id()
	var key = key_name(resource.key_hash) if resource.key_hash != Keys.empty_hash else resource.key
	var storage = key_name(resource.custom_key_hash) if resource.custom_key_hash != Keys.empty_hash else resource.custom_key
	var value = resource.value
	match id:
		"effect":
			match int(resource.storage_method):
				0:
					var definitions = [{"kind": "sum", "key": key, "value": resource.get_applied_value(_player)}]
					if not SUPPORTED.has(key) and not key.begins_with("gain_"):
						definitions.push_back({"kind": "unknown", "label": tr(key.to_upper())})
					return definitions
				1:
					if storage in ["unique_weapon_effects", "additional_weapon_effects", "tier_iv_weapon_effects", "tier_i_weapon_effects", "weapon_scaling_stats", "specific_items_price", "extra_item_in_crate"]:
						return [{"kind": "key_value", "storage": storage, "key": key, "value": value}]
				2:
					if SUPPORTED.has(key):
						return [{"kind": "replace", "key": key, "value": value, "previous": read(resource, "base_value", 0)}]
				3, 4:
					if storage in ["remove_shop_items", "minimum_weapon_cooldowns", "maximum_weapon_cooldowns"]:
						return [{"kind": "append", "storage": storage, "entry": key if int(resource.storage_method) == 3 else [key, value]}]
		"stat_gains_modifications":
			return [{"kind": "stat_gains", "stats": resource.stats_modified.duplicate(), "value": value}]
		"gain_stat_for_every_stat":
			return [{"kind": "link", "storage": "stat_links", "entry": [key, value, resource.stat_scaled, resource.nb_stat_scaled, resource.perm_stats_only]}]
		"class_bonus":
			return [{"kind": "class_bonus", "storage": "weapon_class_bonus", "entry": [resource.set_id, resource.stat_name, value]}]
		"weapon_type_bonus":
			return [{"kind": "type_bonus", "storage": "weapon_type_bonus", "entry": [resource.weapon_type, resource.stat_name, value]}]
		"temp_stats_per_interval":
			return [{"kind": "interval", "key": key, "value": value, "interval": resource.interval, "reset_on_hit": resource.reset_on_hit}]
		"double_key_value":
			if storage == "gain_stat_for_equipped_item_with_stat":
				return [{"kind": "on_item_gain", "storage": storage, "entry": [key, value, resource.key2, resource.value2]},
					{"kind": "unknown", "label": "Будущие бонусы от покупок"}]
		"stat_cap":
			var cap_value = value
			if resource.set_cap_to_current_stat != "":
				cap_value = Utils.get_stat(Keys.generate_hash(resource.set_cap_to_current_stat), _player)
			return [{"kind": "replace", "key": key, "value": cap_value, "previous": 1000000}]
		"weapon_cooldown":
			return [{"kind": "append", "storage": key, "entry": value}]
		"burn_chance":
			return [{"kind": "burn", "burn": burn(resource.burning_data)}]
		"weapon_burning":
			return [{"kind": "burn", "burn": burn(resource.burning_data)}]
		"weapon_exploding":
			return [{"kind": "weapon_effect", "effect": {"kind": "explosion", "chance": read(resource, "chance", 1.0)}}]
		"weapon_stack":
			return [{"kind": "weapon_effect", "effect": {"kind": "stack", "stat": resource.stat_name, "value": value, "family": key_name(resource.weapon_stacked_id_hash)}}]
		"weapon_gain_stat_for_every_stat":
			return [{"kind": "weapon_effect", "effect": {"kind": "weapon_link", "stat": resource.increased_stat_name, "scaled": resource.stat_scaled, "per": resource.nb_stat_scaled, "value": value}}]
		"weapon_damage_multiplier_if_stat":
			return [{"kind": "weapon_effect", "effect": {"kind": "threshold", "stat": resource.stat_name, "value": value, "multiplier": resource.damage_multiplier}}]
		"chance_stat_damage":
			var trigger = event_trigger(storage)
			if trigger != "unknown":
				return [{"kind": "source", "source": {"kind": "proc", "damage": value if key == "" else 0.0,
					"scaling": [] if key == "" else [[key, value / 100.0]], "chance": resource.chance / 100.0, "trigger": trigger}}]
		"item_exploding", "item_exploding_and_burn":
			var trigger = event_trigger(key)
			if trigger != "unknown" and resource.stats != null:
				return [{"kind": "source", "source": {"kind": "proc", "damage": resource.stats.damage,
					"scaling": stat_pairs(resource.stats.scaling_stats), "chance": resource.chance, "aoe": true, "trigger": trigger}}]
	if resource.get("stats") != null and resource.get("spawn_cooldown") != null:
		return [{"kind": "source", "source": {"kind": "structure", "count": max(1, value), "stats": stats(resource.stats),
			"pet": read(resource, "is_pet", false), "spawn_interval": resource.spawn_cooldown}}]
	if resource.get("burning_data") != null:
		return [{"kind": "burn", "burn": burn(resource.burning_data)}]
	return [{"kind": "unknown", "label": tr(key.to_upper()) if key != "" else id}]


func burn(resource) -> Dictionary:
	if resource == null or resource.chance <= 0:
		return {}
	return {"damage": resource.damage, "duration": resource.duration, "chance": resource.chance,
		"spread": resource.spread, "scaling": stat_pairs(resource.scaling_stats)}


func effect_array(name: String, values: Array) -> Array:
	var result = []
	for value in values:
		if value is Array:
			var entry = []
			for part in value:
				entry.push_back(part if part is int or part is float or part is bool or part is String else null)
			if entry.size() > 0 and name in ["stat_links", "unique_weapon_effects", "additional_weapon_effects", "tier_iv_weapon_effects", "tier_i_weapon_effects", "weapon_scaling_stats", "specific_items_price", "weapon_class_bonus", "extra_item_in_crate", "gain_stat_for_equipped_item_with_stat"]:
				entry[0] = key_name(entry[0])
			if name in ["stat_links", "gain_stat_for_equipped_item_with_stat"] and entry.size() > 2:
				entry[2] = key_name(entry[2])
			if name in ["weapon_type_bonus", "weapon_class_bonus"] and entry.size() > 1:
				entry[1] = key_name(entry[1])
			result.push_back(entry)
		elif value is int or value is float or value is String:
			result.push_back(value)
	return result


func reroll_pool(data: Dictionary, context: Dictionary, options: Dictionary) -> Dictionary:
	var tier_data = ItemService.get("_tiers_data")
	var result = {"available": options.get("available", false), "price": options.get("price", 0.0),
		"draws": options.get("draws", 0), "pool": [], "coverage": 1.0, "notes": []}
	if tier_data == null or not result.available or result.draws <= 0:
		return result
	var upgrade_mode = context.get("mode", "shop") == "upgrade"
	var level = int(options.get("level", data.level))
	var wave = level if upgrade_mode else int(data.wave)
	var probabilities = tier_probabilities(tier_data, wave, State.new(data).stat("stat_luck"))
	if upgrade_mode and level % 5 == 0:
		probabilities = [0.0, 0.0, 0.0, 0.0]
		probabilities[1 if level == 5 else (2 if level in [10, 15, 20] else 3)] = 1.0
	var population = []
	var character = RunData.get_player_character(_player)
	for tier in min(4, tier_data.size()):
		if probabilities[tier] <= 0.0:
			continue
		for type in ([4] if upgrade_mode else [1, 2]):
			var pool_tier = tier
			if type == 2:
				pool_tier = int(clamp(tier, data.effects.get("min_weapon_tier", 0), data.effects.get("max_weapon_tier", 3)))
			var pool = ItemService.get_pool(pool_tier, type)
			if not upgrade_mode:
				var backup = pool.duplicate()
				ItemService.update_pools(pool, backup, _player, pool_tier, type)
			var eligible = []
			for resource in pool:
				if allowed(resource, type, data, options, character):
					eligible.push_back(resource)
			if eligible.empty():
				continue
			var weights = pool_weights(eligible, type, data, character)
			var type_probability = 1.0 if upgrade_mode else (0.35 if type == 2 else 0.65)
			if data.effects.get("effect_no_weapon_in_shop", 0) > 0 or data.effects.get("weapon_slot", 6) <= 0:
				type_probability = 0.0 if type == 2 else 1.0
			for index in eligible.size():
				population.push_back({"resource": eligible[index], "weight": probabilities[tier] * type_probability * weights[index]})
	var sampled = weighted_sample(population, MAX_SAMPLES)
	for entry in sampled:
		var definition = item(entry.resource)
		apply_profile(definition, context)
		definition.price = 0 if upgrade_mode else ItemService.get_value(RunData.current_wave, entry.resource.value, _player, true, entry.resource is WeaponData, entry.resource.my_id_hash)
		if upgrade_mode:
			var modifier = float(data.effects.get("level_upgrades_modifications", 0))
			for current in definition.effects:
				if current.has("value"):
					current.value = int(current.value * (1.0 + modifier / 100.0))
		result.pool.push_back({"item": definition, "weight": entry.weight})
	if not upgrade_mode and (data.wave <= 5 or data.effects.get("minimum_weapons_in_shop", 0) > 0):
		result.coverage = 0.7
		result.notes.push_back("Гарантированные оружейные слоты меняют распределение")
	if not data.effects.get("guaranteed_shop_items", []).empty() or abs(float(data.effects.get("stat_evolution", 0))) > 2.0 or float(data.effects.get("stat_curse", 0)) > 0:
		result.coverage = min(result.coverage, 0.7)
		result.notes.push_back("Гарантированные и случайно изменённые предметы оценены частично")
	return result


static func apply_profile(definition: Dictionary, context: Dictionary) -> void:
	if definition.kind == "weapon":
		var calibration = context.get("calibration", {})
		definition["calibration"] = calibration.get(definition.get("family", definition.id), calibration.get("ranged" if definition.stats.ranged else "melee", 1.0))


func allowed(resource: Resource, type: int, data: Dictionary, options: Dictionary, character: Resource) -> bool:
	if options.get("excluded", []).has(resource.my_id):
		return false
	var player = RunData.players_data[_player]
	for banned in player.banned_items:
		if key_name(banned) == resource.my_id:
			return false
	if type == 4:
		return not (RunData.current_wave < RunData.nb_of_waves and character.banned_upgrades.has(resource.upgrade_id))
	if type == 2:
		if resource.type == 0 and data.effects.get("no_melee_weapons", 0) > 0:
			return false
		if resource.type == 1 and data.effects.get("no_ranged_weapons", 0) > 0:
			return false
		if data.effects.get("no_duplicate_weapons", 0) > 0:
			for owned in data.weapons:
				if owned.family == resource.weapon_id and (resource.tier < owned.tier or (owned.id == resource.my_id and resource.upgrades_into == null)):
					return false
	else:
		if data.wave < data.last_wave:
			if character.banned_items.has(resource.my_id):
				return false
			for group in character.banned_item_groups:
				if ItemService.item_groups.get(group, []).has(resource.my_id):
					return false
		for tag in data.effects.get("remove_shop_items", []):
			if resource.tags.has(key_name(tag)):
				return false
		var max_nb = int(read(resource, "max_nb", -1))
		if max_nb > 0:
			var count = State.new(data).item_count(resource.my_id)
			if count >= max_nb:
				return false
	return true


func pool_weights(pool: Array, type: int, data: Dictionary, character: Resource) -> Array:
	var all = []
	var wanted = []
	var related = []
	var other = []
	var families = {}
	var sets = {}
	for weapon in data.weapons:
		families[weapon.family] = true
		for set_id in weapon.sets:
			sets[set_id] = true
	for index in pool.size():
		all.push_back(index)
		if type == 2:
			if families.has(pool[index].weapon_id):
				wanted.push_back(index)
			else:
				other.push_back(index)
			var matches = families.has(pool[index].weapon_id)
			for set in pool[index].sets:
				matches = matches or sets.has(set.my_id)
			if matches:
				related.push_back(index)
		elif type == 1:
			for tag in character.wanted_tags:
				if pool[index].tags.has(tag):
					wanted.push_back(index)
					break
	var result = []
	result.resize(pool.size())
	for index in result.size():
		result[index] = 0.0
	var groups = [[all, 1.0]]
	if type == 2:
		var same = clamp(0.23 + max(0.0, (6.0 - data.wave) * 0.07 / 5.0) + min(families.size(), 6) * 0.02, 0.0, 1.0)
		var same_set = clamp(0.35 + max(0.0, (6.0 - data.wave) * 0.2 / 5.0) + min(families.size(), 6) * 0.01, same, 1.0)
		groups = [[wanted, same], [related, same_set - same], [other, 1.0 - same_set]]
	elif type == 1 and not wanted.empty():
		var wanted_chance = 0.1 if data.effects.get("stat_boosted_wanted_item_tag", 0) > 0 else 0.05
		groups = [[wanted, wanted_chance], [all, 1.0 - wanted_chance]]
	for group in groups:
		var indices = group[0] if not group[0].empty() else all
		for index in indices:
			result[index] += group[1] / indices.size()
	return result


static func tier_probabilities(tiers: Array, wave: int, luck_stat: float) -> Array:
	var probabilities = [0.0, 0.0, 0.0, 0.0]
	var covered = 0.0
	var luck = luck_stat / 100.0
	for tier in range(min(4, tiers.size()) - 1, -1, -1):
		var row = tiers[tier]
		var bonus = max(0.0, ((wave - 1) - row[5]) * row[7])
		bonus = bonus * (1.0 + luck) if luck >= 0 else bonus / (1.0 + abs(luck))
		var chance = clamp(min(row[6] + bonus, row[8]), 0.0, 1.0)
		probabilities[tier] = max(0.0, chance - covered)
		covered = max(covered, chance)
	probabilities[0] += 1.0 - covered
	return probabilities


static func weighted_sample(population: Array, limit: int) -> Array:
	if population.size() <= limit:
		return population
	var total = 0.0
	for entry in population:
		total += entry.weight
	if total <= 0.0:
		return []
	var result = []
	var cursor = 0
	var cumulative = population[0].weight
	for index in limit:
		var target = total * (index + 0.5) / limit
		while cumulative < target and cursor < population.size() - 1:
			cursor += 1
			cumulative += population[cursor].weight
		result.push_back({"resource": population[cursor].resource, "weight": 1.0 / limit})
	return result


func stat_pairs(values: Array) -> Array:
	var result = []
	for entry in values:
		if entry is Array and entry.size() >= 2:
			result.push_back([key_name(entry[0]), entry[1]])
	return result


static func key_name(value) -> String:
	return str(Keys.hash_to_string.get(value, "")) if value is int else str(value)


static func read(object: Object, property: String, fallback):
	var value = object.get(property)
	return value if value != null else fallback


static func event_trigger(key: String) -> String:
	if "kill" in key or "death" in key:
		return "kill"
	if "pickup" in key or "consumable" in key or "gold" in key:
		return "pickup"
	if "hit" in key or "damage_taken" in key:
		return "hit"
	return "unknown"
