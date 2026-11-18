extends Reference

var data: Dictionary
var _stat_cache = {}
var _stat_context = null


func _init(source: Dictionary = {}) -> void:
	data = source.duplicate(true)
	for key in ["effects", "sets", "derived", "temporary", "item_values"]:
		if not data.has(key):
			data[key] = {}
	for key in ["weapons", "items", "applied_sets", "unknown", "sources", "intervals", "link_sources", "item_gain_sources", "fired_gains"]:
		if not data.has(key):
			data[key] = []
	data["cash"] = float(data.get("cash", 0.0))
	data["currency"] = float(data.get("currency", data.cash))
	data["currency_kind"] = data.get("currency_kind", "gold")
	for item in data.items:
		data.item_values[item.id] = {"sale": item.get("crate_recycle_value", 1.0), "max": item.get("max_nb", -1)}


func fork():
	return get_script().new(data)


func apply(action: Dictionary) -> Dictionary:
	var candidate = fork()
	var result = candidate._apply(action)
	if result.ok:
		data = candidate.data
		_stat_cache.clear()
		_stat_context = null
	return result


func _apply(action: Dictionary) -> Dictionary:
	_stat_cache.clear()
	_stat_context = null
	if action.kind == "sell":
		if number("lock_current_weapons") > 0 or number("fog_of_war_permanent") > 0:
			return {"ok": false, "reason": "Продажа недоступна"}
		for index in data.weapons.size():
			var owned = data.weapons[index]
			if owned.get("uid", owned.id) != action.uid:
				continue
			_effects(owned.get("effects", []), -1)
			data.weapons.remove(index)
			data.cash += action.get("value", owned.get("sale_value", 0.0))
			if data.currency_kind == "gold":
				data.currency = data.cash
			rebuild()
			if data.currency_kind == "hp":
				data.currency = raw_stat("stat_max_hp")
			return {"ok": true}
		return {"ok": false, "reason": "Оружие отсутствует"}
	var item = action.get("item", {})
	var cost = max(0.0, float(action.get("cost", 0.0)))
	if cost > data.currency:
		return {"ok": false, "reason": "Не хватает валюты"}
	if item.empty():
		return {"ok": false, "reason": "Нет предмета"}
	if item.get("blocked", "") != "":
		return {"ok": false, "reason": item.blocked}
	if item.get("kind", "item") == "weapon":
		var ranged = item.get("stats", {}).get("ranged", false)
		if (ranged and number("no_ranged_weapons") > 0) or (not ranged and number("no_melee_weapons") > 0):
			return {"ok": false, "reason": "Ограничение персонажа"}
		if item.get("tier", 0) > number("max_weapon_tier", 3):
			return {"ok": false, "reason": "Недоступный уровень оружия"}
		var weapon_type = int(item.get("weapon_type", 1 if ranged else 0))
		var same_type = 0
		var family_present = false
		for owned in data.weapons:
			var owned_type = int(owned.get("weapon_type", 1 if owned.get("stats", {}).get("ranged", false) else 0))
			if owned_type == weapon_type:
				same_type += 1
			family_present = family_present or owned.get("family", owned.id) == item.get("family", item.id)
		var type_limit = number("max_ranged_weapons" if ranged else "max_melee_weapons", 6)
		var needs_merge = data.weapons.size() >= int(number("weapon_slot", 6))
		needs_merge = needs_merge or (weapon_type >= 0 and same_type >= type_limit)
		needs_merge = needs_merge or (number("no_duplicate_weapons") > 0 and family_present)
		if needs_merge:
			var combined = false
			for index in data.weapons.size():
				var owned = data.weapons[index]
				if owned.id != item.id or item.get("upgrade", {}).empty() or number("lock_current_weapons") > 0:
					continue
				if owned.get("flavor", "plain") != "plain" or item.get("flavor", "plain") != "plain":
					return {"ok": false, "reason": "Особое объединение: нужен ручной выбор"}
				var upgrade = item.upgrade
				if upgrade.get("tier", 0) > number("max_weapon_tier", 3):
					continue
				_effects(owned.get("effects", []), -1)
				data.weapons[index] = upgrade.duplicate(true)
				data.weapons[index]["uid"] = owned.get("uid", owned.id)
				data.weapons[index]["calibration"] = owned.get("calibration", 1.0)
				_effects(upgrade.get("effects", []), 1)
				combined = true
				break
			if not combined:
				return {"ok": false, "reason": "Нет свободного слота"}
		else:
			if number("no_duplicate_weapons") > 0:
				for owned in data.weapons:
					if owned.get("family", owned.id) == item.get("family", item.id):
						return {"ok": false, "reason": "Повторное оружие запрещено"}
			data.weapons.push_back(item.duplicate(true))
			_effects(item.get("effects", []), 1)
	else:
		var count = item_count(item.id)
		if item.get("max_nb", -1) > 0 and count >= item.max_nb:
			return {"ok": false, "reason": "Достигнут лимит предмета"}
		if item.get("kind", "item") != "upgrade":
			data.items.push_back(item.duplicate(true))
			data.item_values[item.id] = {"sale": item.get("crate_recycle_value", 1.0), "max": item.get("max_nb", -1)}
		_apply_item_effects(item)
	data.currency -= cost
	if data.currency_kind == "gold":
		data.cash = data.currency
	elif data.currency_kind == "hp":
		data.effects.stat_max_hp = number("stat_max_hp") - cost
	rebuild()
	if data.currency_kind == "hp":
		data.currency = raw_stat("stat_max_hp")
	return {"ok": true}


func _apply_item_effects(item: Dictionary) -> void:
	for effect in item.get("effects", []):
		var key = effect.get("key", "")
		var previous = number(key)
		_effect(effect, 1)
		if item.get("kind", "item") != "item" or not key.begins_with("stat_") or number(key) <= previous:
			continue
		for rule in data.effects.get("gain_stat_for_equipped_item_with_stat", []):
			if rule.size() < 4 or rule[2] != key:
				continue
			data.effects[rule[0]] = number(rule[0]) + rule[1]
			var names = []
			for source in data.item_gain_sources:
				if source.from == key and source.to == rule[0] and not names.has(source.name):
					names.push_back(source.name)
			data.fired_gains.push_back({"from": key, "to": rule[0], "sources": names})


func number(key: String, fallback: float = 0.0) -> float:
	var value = data.effects.get(key, fallback)
	return float(value) if value is int or value is float else fallback


func item_count(id: String) -> int:
	var count = 0
	for owned in data.items:
		if owned.id == id:
			count += 1
	return count


func raw_stat(key: String) -> float:
	return number(key) * (1.0 + number("gain_" + key) / 100.0)


func stat(key: String, context: Dictionary = {}) -> float:
	if _stat_context != context:
		_stat_cache.clear()
		_stat_context = context
	if _stat_cache.has(key):
		return _stat_cache[key]
	var value = raw_stat(key) + temporary_stat(key, context)
	var gain = 1.0 + number("gain_" + key) / 100.0
	for link in data.effects.get("stat_links", []):
		if link.size() < 5 or link[0] != key or float(link[3]) == 0.0:
			continue
		value += int(float(link[1]) * scaled_value(str(link[2]), context, bool(link[4])) / float(link[3])) * gain
	var caps = {"stat_max_hp": "hp_cap", "stat_speed": "speed_cap", "stat_dodge": "dodge_cap", "stat_curse": "curse_cap", "stat_crit_chance": "crit_chance_cap"}
	if caps.has(key):
		value = min(value, number(caps[key], 1000000.0))
	_stat_cache[key] = value
	return value


func temporary_stat(key: String, context: Dictionary) -> float:
	var gain = 1.0 + number("gain_" + key) / 100.0
	if context.get("preview", false):
		return float(data.temporary.get(key, 0.0)) * gain
	var value = 0.0
	for interval in data.intervals:
		if interval.key != key or interval.interval <= 0:
			continue
		var exposure = context.get("duration", 60.0) / 2.0
		if interval.get("reset_on_hit", false):
			exposure = min(exposure, 1.0 / max(0.02, context.get("hit_rate", 0.2)))
		value += interval.value * floor(exposure / interval.interval) * gain
	return value


func scaled_value(key: String, context: Dictionary, permanent_only: bool = true) -> float:
	match key:
		"materials":
			return data.cash
		"free_weapon_slots":
			return float(max(0, int(number("weapon_slot", 6)) - data.weapons.size()))
		"different_item", "common_item", "legendary_item", "duplicate_item":
			var ids = {}
			for item in data.items:
				if key != "duplicate_item" and (item.id.begins_with("character_") or item.id == "item_tumor"):
					continue
				if key == "common_item" and item.get("tier", 0) != 0:
					continue
				if key == "legendary_item" and item.get("tier", 0) != 3:
					continue
				ids[item.id] = ids.get(item.id, 0) + 1
			if key == "duplicate_item":
				for weapon in data.weapons:
					var family = weapon.get("family", weapon.id)
					ids[family] = ids.get(family, 0) + 1
				var duplicates = 0
				for amount in ids.values():
					duplicates += max(0, amount - 1)
				return float(duplicates)
			return float(ids.size())
		"structure", "pet", "stat_pet":
			var count = 0
			var sources = data.sources.duplicate()
			for item in data.items + data.weapons:
				sources.append_array(item.get("sources", []))
			for source in sources:
				if not source.get("kind", "") in ["structure", "pet"]:
					continue
				if key == "structure" and (source.kind == "structure" or source.get("is_structure", false)):
					count += 1
				elif key != "structure" and (source.kind == "pet" or source.get("pet", false)):
					count += 1
			if key == "structure":
				count += item_count("item_pocket_factory")
			else:
				count += int(number("stat_jellyshield_count"))
			return float(count)
		"living_enemy", "burning_enemy", "living_tree", "percent_player_missing_health":
			return context.get(key, 0.0)
	if key.begins_with("item_"):
		return float(item_count(key))
	return raw_stat(key) + (0.0 if permanent_only else temporary_stat(key, context))


func rebuild() -> void:
	_effects(data.applied_sets, -1)
	data.applied_sets = []
	var counts = {}
	for weapon in data.weapons:
		for set_id in weapon.get("sets", []):
			counts[set_id] = data.weapons.size() if number("all_weapons_count_for_sets") > 0 else counts.get(set_id, 0) + 1
	for id in counts:
		var count = counts[id] + int(number("weapon_set_bonus"))
		var bonuses = data.sets.get(id, [])
		if count >= 2 and not bonuses.empty():
			var effects = bonuses[min(count - 2, bonuses.size() - 1)]
			_effects(effects, 1)
			data.applied_sets.append_array(effects.duplicate(true))
	data["set_counts"] = counts
	for kind in ["unique", "additional", "tier_iv", "tier_i"]:
		for bonus in data.derived.get(kind, []):
			data.effects[bonus[0]] = number(bonus[0]) - bonus[1]
		data.derived[kind] = []
		var unique = {}
		var amount = 0
		for weapon in data.weapons:
			unique[weapon.get("family", weapon.id)] = true
			if (kind == "tier_iv" and weapon.get("tier", 0) >= 3) or (kind == "tier_i" and weapon.get("tier", 0) == 0):
				amount += 1
		if kind == "unique":
			amount = unique.size()
		elif kind == "additional":
			amount = data.weapons.size()
		for bonus in data.effects.get(kind + "_weapon_effects", []):
			var value = bonus[1] * amount
			data.effects[bonus[0]] = number(bonus[0]) + value
			data.derived[kind].push_back([bonus[0], value])


func _effects(effects: Array, direction: int) -> void:
	for effect in effects:
		_effect(effect, direction)


func _effect(effect: Dictionary, direction: int) -> void:
	var key = effect.get("key", "")
	var value = effect.get("value", 0.0)
	match effect.get("kind", "unknown"):
		"sum":
			data.effects[key] = number(key) + value * direction
		"replace":
			data.effects[key] = value if direction > 0 else effect.get("previous", 0.0)
		"stat_gains":
			for stat in effect.stats:
				data.effects["gain_" + stat] = number("gain_" + stat) + value * direction
		"link", "append", "type_bonus", "class_bonus", "on_item_gain":
			var storage = effect.get("storage", key)
			if not data.effects.has(storage):
				data.effects[storage] = []
			if direction > 0:
				data.effects[storage].push_back(effect.entry.duplicate(true) if effect.entry is Array or effect.entry is Dictionary else effect.entry)
				if effect.kind == "link":
					data.link_sources.push_back({"from": effect.entry[2], "to": effect.entry[0], "name": effect.get("source_name", "Предмет")})
				elif effect.kind == "on_item_gain":
					data.item_gain_sources.push_back({"from": effect.entry[2], "to": effect.entry[0], "name": effect.get("source_name", "Предмет")})
			else:
				for index in data.effects[storage].size():
					if str(data.effects[storage][index]) == str(effect.entry):
						data.effects[storage].remove(index)
						break
		"key_value":
			var storage = effect.storage
			if not data.effects.has(storage):
				data.effects[storage] = []
			var found = false
			for entry in data.effects[storage]:
				if entry[0] == key:
					entry[1] += value * direction
					found = true
					break
			if not found:
				data.effects[storage].push_back([key, value * direction])
		"interval":
			if direction > 0:
				data.intervals.push_back(effect.duplicate(true))
			else:
				for index in data.intervals.size():
					if str(data.intervals[index]) == str(effect):
						data.intervals.remove(index)
						break
		"source", "burn", "weapon_effect":
			pass
		_:
			var label = effect.get("label", key)
			if not data.unknown.has(label):
				data.unknown.push_back(label)
