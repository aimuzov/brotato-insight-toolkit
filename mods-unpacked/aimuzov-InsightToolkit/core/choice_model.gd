extends Reference


# Roughly one early upgrade in each stat, to keep unlike stats comparable.
const PREFERENCE_UNIT = {
	"stat_max_hp": 3, "stat_hp_regeneration": 2, "stat_lifesteal": 1, "stat_percent_damage": 5,
	"stat_melee_damage": 2, "stat_ranged_damage": 1, "stat_elemental_damage": 1, "stat_engineering": 2,
	"stat_attack_speed": 5, "stat_crit_chance": 3, "stat_armor": 1, "stat_dodge": 3,
	"stat_speed": 3, "stat_range": 15, "stat_harvesting": 5, "stat_luck": 5, "stat_curse": 3, "xp_gain": 10
}


static func evaluate(state, context: Dictionary) -> Dictionary:
	context = context.duplicate()
	var count_factor = max(0.01, 1.0 + state.number("number_of_enemies") / 100.0) / max(0.01, 1.0 + context.get("base_enemy_count", 0.0) / 100.0)
	var damage_factor = max(0.01, 1.0 + state.stat("enemy_damage", context) / 100.0) / max(0.01, 1.0 + context.get("base_enemy_damage", 0.0) / 100.0)
	context["density"] = context.get("density", 2.0) * count_factor
	context["mean_hit"] = context.get("mean_hit", 4.0) * damage_factor
	context["max_hit"] = context.get("max_hit", 8.0) * damage_factor
	context["hit_rate"] = context.get("hit_rate", 0.15) * sqrt(count_factor)
	var duration = max(1.0, float(context.get("duration", 60.0)))
	var unknown = state.data.unknown.duplicate()
	var dps = 0.0
	var healing_rate = 0.0
	var attacks = 0.0
	for weapon in state.data.weapons:
		var output = weapon_output(state, weapon, context)
		dps += output.dps
		attacks += output.attacks
		healing_rate += output.healing
		unknown.append_array(output.unknown)
	var preferences = state.data.get("preferences", [])
	var affinity = 0.0
	for key in preferences:
		if PREFERENCE_UNIT.has(key):
			affinity += state.stat(key, context) / float(PREFERENCE_UNIT[key])
	var sources = state.data.sources.duplicate(true)
	for object in state.data.items + state.data.weapons:
		for tag in object.get("tags", []):
			if not PREFERENCE_UNIT.has(tag) and tag in preferences:
				affinity += 1.0
				break
		sources.append_array(object.get("sources", []))
		for label in object.get("unknown", []):
			unknown.push_back(label)
		for effect in object.get("effects", []):
			if effect.kind == "unknown":
				var label = effect.get("label", "Неизвестный эффект")
				unknown.push_back(label)
	for source in sources:
		var output = source_output(state, source, context, attacks)
		dps += output.dps
		healing_rate += output.healing
		unknown.append_array(output.unknown)
	var hp = max(1.0, state.stat("stat_max_hp", context))
	var armor = state.stat("stat_armor", context)
	var armor_coefficient = 1.0 / (1.0 + abs(armor) / 15.0)
	if armor < 0:
		armor_coefficient = 2.0 - armor_coefficient
	var dodge = clamp(state.stat("stat_dodge", context) / 100.0, 0.0, 0.9)
	var hit_rate = max(0.0, context.get("hit_rate", 0.2))
	var mean_hit = max(1.0, context.get("mean_hit", hp * 0.18))
	var max_hit = max(mean_hit, context.get("max_hit", hp * 0.35))
	var mobility = clamp(1.0 + state.stat("stat_speed", context) / 250.0, 0.6, 1.35)
	# Approximate angular coverage from the pet's 30px hit radius and 100px orbit.
	var coverage = min(1.0, max(0.0, state.number("jellyshield_count")) * asin(0.3) / PI)
	var exposure = 1.0 - coverage * clamp(context.get("projectile_fraction", 0.5), 0.0, 1.0)
	var incoming = exposure * hit_rate * mean_hit * duration * armor_coefficient * (1.0 - dodge) / mobility
	var regen = state.stat("stat_hp_regeneration", context)
	var regen_rate = (1.0 + max(0.0, regen - 1.0) / 2.25) / 5.0 if regen > 0 else 0.0
	var sustain = (regen_rate + min(healing_rate, 10.0)) * duration
	var healing = min(sustain, incoming)
	var guaranteed_ehp = hp / max(0.05, armor_coefficient)
	var ehp = (hp + healing) / max(0.05, armor_coefficient) / max(0.2, 1.0 - dodge * 0.65) * mobility / max(0.05, exposure)
	var burst = max_hit * armor_coefficient / hp
	var risk = max(0.0, burst - 0.45) + max(0.0, (incoming - healing) / hp - 1.0) * 0.15
	var clearance = dps / max(0.01, 1.0 + state.stat("enemy_health", context) / 100.0) / count_factor
	return {"dps": max(0.0, dps), "clearance": max(0.0, clearance), "ehp": ehp, "burst_ehp": guaranteed_ehp,
		"risk": risk, "healing": healing, "incoming": incoming, "hp": hp,
		"affinity": affinity, "future_money": future_income(state, context), "unknown": unique(unknown), "unknown_counts": counts(unknown)}


static func weapon_output(state, weapon: Dictionary, context: Dictionary) -> Dictionary:
	var stats = weapon.get("stats", {}).duplicate(true)
	if stats.empty():
		return {"dps": 0.0, "attacks": 0.0, "healing": 0.0, "unknown": ["Нет модели оружия"]}
	var unknown = weapon.get("unknown", []).duplicate()
	var ranged = stats.get("ranged", true)
	var structure = stats.get("structure", false)
	for bonus in state.data.effects.get("weapon_type_bonus", []):
		if (ranged and int(bonus[0]) == 1) or (not ranged and int(bonus[0]) == 0):
			var field = stat_field(bonus[1])
			stats[field] = float(stats.get(field, 0.0)) + float(bonus[2])
	var class_damage = 0.0
	for bonus in state.data.effects.get("weapon_class_bonus", []):
		if not weapon.get("sets", []).has(bonus[0]):
			continue
		if bonus[1] == "stat_percent_damage":
			class_damage += bonus[2] / 100.0
		else:
			var multiplier = 0.01 if bonus[1] in ["lifesteal", "crit_damage"] else 1.0
			var field = stat_field(bonus[1])
			stats[field] = float(stats.get(field, 0.0)) + bonus[2] * multiplier
	var base_damage = float(stats.get("damage", 0.0))
	for effect in weapon.get("weapon_effects", []):
		match effect.kind:
			"stack":
				var count = 0
				for other in state.data.weapons:
					if other.get("family", other.id) == effect.family:
						count += 1
				stats[effect.stat] = float(stats.get(effect.stat, 0.0)) + effect.value * max(0, count - 1)
			"weapon_link":
				stats[effect.stat] = float(stats.get(effect.stat, 0.0)) + int(effect.value * state.scaled_value(effect.scaled, context) / max(1.0, effect.per))
			"threshold":
				if state.number(effect.stat) >= effect.value:
					stats.damage = round(float(stats.get("damage", 0.0)) * effect.multiplier)
			"explosion":
				stats["exploding"] = true
			_:
				unknown.push_back(effect.get("label", "Особый эффект оружия"))
	base_damage = float(stats.get("damage", base_damage))
	var scaling = stats.get("scaling", []).duplicate(true)
	for entry in (state.data.effects.get("weapon_scaling_stats", []) if not structure or stats.get("pet", false) else []):
		if entry.size() >= 2:
			var found = false
			for existing in scaling:
				if existing[0] == entry[0]:
					existing[1] += entry[1] / 100.0
					found = true
			if not found:
				scaling.push_back([entry[0], entry[1] / 100.0])
	for scale in scaling:
		base_damage += state.stat(scale[0], context) * scale[1]
	var damage_bonus = 1.0 + state.stat("stat_percent_damage", context) / 100.0 + class_damage
	if structure:
		damage_bonus = 1.0 + state.stat("structure_percent_damage", context) / 100.0 + class_damage
		if stats.get("pet", false):
			damage_bonus += state.stat("stat_percent_damage", context) / 100.0
	if stats.get("exploding", false):
		damage_bonus += state.number("explosion_damage") / 100.0
	var damage = max(1.0, round(round(base_damage) * damage_bonus))
	var crit = clamp(float(stats.get("crit_chance", 0.0)) + state.stat("stat_crit_chance", context) / 100.0, 0.0, 1.0)
	if structure and state.number("structures_can_crit") <= 0:
		crit = float(stats.get("crit_chance", 0.0))
	var crit_multiplier = float(stats.get("crit_damage", 1.5)) + state.number("bonus_crit_damage") / 100.0
	damage *= 1.0 + crit * max(0.0, crit_multiplier - 1.0)
	var speed = (state.stat("stat_attack_speed", context) + float(stats.get("attack_speed_mod", 0.0))) / 100.0
	if structure:
		speed = state.stat("structure_attack_speed", context) / 100.0
	var cooldown = max(2.0, float(stats.get("cooldown", 60.0)))
	cooldown = max(2.0, int(cooldown * (1.0 + abs(speed)) if speed < 0 else cooldown / (1.0 + speed)))
	var cycle = max(0.04, cooldown / 60.0 + float(stats.get("animation", 0.0)))
	var minimum = state.data.effects.get("minimum_weapon_cooldowns", [])
	var maximum = state.data.effects.get("maximum_weapon_cooldowns", [])
	for limit in minimum:
		cycle = max(cycle, float(limit) / 60.0)
	for limit in maximum:
		cycle = min(cycle, max(0.04, float(limit) / 60.0))
	var shots = int(stats.get("additional_cooldown_every_x_shots", -1))
	if shots > 0:
		cycle += cooldown / 60.0 * max(0.0, float(stats.get("additional_cooldown_multiplier", 1.0)) - 1.0) / shots
	var projectiles = max(1, int(stats.get("projectiles", 1)) + int(state.number("projectiles"))) if ranged else 1
	var accuracy = clamp(float(stats.get("accuracy", 1.0)) + state.number("accuracy") / 100.0, 0.05, 1.0)
	var range_value = float(stats.get("range", 150.0)) + state.stat("stat_range", context) * (1.0 if ranged else 0.5)
	if structure:
		range_value = float(stats.get("range", 150.0)) + state.stat("structure_range", context)
	var uptime = clamp(0.65 + range_value / (1000.0 if ranged else 600.0), 0.2, 1.0)
	if not ranged:
		uptime *= clamp(1.0 + state.stat("stat_speed", context) / 200.0, 0.5, 1.2)
	var density = max(0.0, context.get("density", 2.0))
	var boss_fraction = clamp(context.get("boss_fraction", 0.0), 0.0, 1.0)
	var targets = 1.0
	if ranged:
		targets += extra_targets(int(stats.get("piercing", 0)) + int(state.number("piercing")), 1.0 - float(stats.get("piercing_reduction", 0.5)) + state.number("piercing_damage") / 100.0, density)
		targets += extra_targets(int(stats.get("bounce", 0)) + int(state.number("bounce")), 1.0 - float(stats.get("bounce_reduction", 0.5)) + state.number("bounce_damage") / 100.0, density)
	else:
		targets += min(3.0, density * max(0.0, range_value) / 400.0)
		if stats.get("return_damage", false):
			targets *= 1.5
	if stats.get("exploding", false):
		targets += min(4.0, density * max(0.1, 1.0 + state.number("explosion_size") / 100.0))
	targets = lerp(targets, 1.0, boss_fraction)
	var attacks = projectiles / cycle * accuracy * uptime
	var dps = damage * attacks * targets
	var calibration = clamp(float(weapon.get("calibration", 1.0)), 0.2, 5.0)
	dps *= calibration
	var burn = stats.get("burn", {})
	for effect in weapon.get("effects", []):
		if effect.kind == "burn":
			burn = effect.get("burn", {})
	if not burn.empty():
		dps += burning_dps(state, burn, context, attacks, targets)
	for object in state.data.items:
		for effect in object.get("effects", []):
			if effect.kind == "burn":
				dps += burning_dps(state, effect.burn, context, attacks, targets) / max(1, state.data.weapons.size())
	var lifesteal = clamp(float(stats.get("lifesteal", 0.0)) + state.stat("stat_lifesteal", context) / 100.0, 0.0, 1.0)
	if structure:
		lifesteal = float(stats.get("lifesteal", 0.0))
	return {"dps": 0.0 if stats.get("healing", false) else dps, "attacks": attacks,
		"healing": damage * attacks if stats.get("healing", false) else min(10.0, attacks * lifesteal), "unknown": unknown}


static func extra_targets(count: int, retention: float, density: float) -> float:
	var total = 0.0
	for index in min(max(0, count), 12):
		total += pow(clamp(retention, 0.0, 1.5), index + 1) * clamp(density / 3.0, 0.0, 1.0)
	return total


static func burning_dps(state, burn: Dictionary, context: Dictionary, attacks: float, targets: float) -> float:
	var damage = float(burn.get("damage", 0.0))
	for scale in burn.get("scaling", []):
		damage += state.stat(scale[0], context) * scale[1]
	damage = max(0.0, damage * (1.0 + state.stat("stat_percent_damage", context) / 100.0))
	var duration = max(0.0, burn.get("duration", 0.0) + state.number("burning_duration"))
	var coverage = clamp(attacks * clamp(burn.get("chance", 0.0), 0.0, 1.0) * duration, 0.0, 1.0)
	return damage * coverage * targets * max(0.1, 1.0 + state.number("burning_speed") / 100.0)


static func source_output(state, source: Dictionary, context: Dictionary, attacks: float) -> Dictionary:
	if source.get("kind", "") == "structure":
		var proxy = source.duplicate(true)
		proxy["id"] = "structure"
		proxy["stats"] = source.get("stats", {}).duplicate(true)
		proxy.stats["structure"] = true
		proxy.stats["pet"] = source.get("pet", false)
		var output = weapon_output(state, proxy, context)
		output.dps *= source.get("count", 1)
		return output
	var events = 0.0
	match source.get("trigger", "interval"):
		"kill":
			events = context.get("kill_rate", 1.0)
		"pickup":
			events = context.get("pickup_rate", 1.0)
		"hit":
			events = context.get("hit_rate", 0.2)
		"attack":
			events = attacks
		_:
			events = 1.0 / max(0.1, source.get("interval", 1.0))
	var damage = float(source.get("damage", 0.0))
	for scale in source.get("scaling", []):
		damage += state.stat(scale[0], context) * scale[1]
	damage *= max(0.0, 1.0 + state.stat("stat_percent_damage", context) / 100.0)
	var targets = 1.0 + min(3.0, context.get("density", 1.0)) if source.get("aoe", false) else 1.0
	return {"dps": max(0.0, damage) * events * clamp(source.get("chance", 1.0), 0.0, 1.0) * targets,
		"healing": 0.0, "unknown": source.get("unknown", [])}


static func future_income(state, context: Dictionary) -> float:
	var horizon = int(clamp(context.get("horizon", 3), 0, 5))
	var harvest = state.stat("stat_harvesting", context)
	var growth = 1.05 + state.number("harvesting_growth") / 100.0
	var total = 0.0
	for index in horizon:
		var endless = int(state.data.get("wave", 1)) + index >= int(state.data.get("last_wave", 20))
		total += harvest * pow(0.85, index)
		harvest *= 0.8 if endless else growth
	var future_spend = context.get("income", 80.0) * horizon
	var count_factor = max(0.01, 1.0 + state.number("number_of_enemies") / 100.0) / max(0.01, 1.0 + context.get("base_enemy_count", 0.0) / 100.0)
	total += future_spend * (count_factor - 1.0)
	if state.data.currency_kind == "gold":
		total -= future_spend * state.number("items_price") / 100.0
	var xp = max(-100.0, state.stat("xp_gain", context)) / 100.0
	total += xp * horizon * 8.0
	var luck = max(-100.0, state.stat("stat_luck", context))
	total += luck / 100.0 * horizon * 4.0
	var crates = context.get("crates_per_wave", 0.5 + max(0.0, luck) / 200.0) * horizon
	for extra in state.data.effects.get("extra_item_in_crate", []):
		var item = state.data.item_values.get(extra[0], {"sale": 1.0, "max": -1})
		var expected = crates * clamp(float(extra[1]) / 100.0, 0.0, 1.0)
		if item.max > 0:
			expected = min(expected, max(0, item.max - state.item_count(extra[0])))
		total += expected * item.sale * 0.85
	return total


static func improvement(before: Dictionary, after: Dictionary, context: Dictionary) -> float:
	var budget = max(40.0, context.get("income", 80.0)) * 1.8
	var deficit = max(0.0, context.get("required_dps", 0.0) / max(1.0, before.dps) - 1.0)
	var offense = log(max(0.05, after.get("clearance", after.dps)) / max(0.05, before.get("clearance", before.dps)))
	var defense = log(max(1.0, after.ehp) / max(1.0, before.ehp))
	var offense_weight = clamp(0.55 + deficit * 0.25, 0.55, 1.2)
	var defense_weight = clamp(0.45 + before.risk * 0.4, 0.45, 1.5)
	# Character fit is a bounded adjustment to the combat and economy forecast.
	var fit = clamp(after.get("affinity", 0.0) - before.get("affinity", 0.0), -3.0, 3.0) * 0.04
	return budget * (fit + offense * offense_weight + defense * defense_weight + (before.risk - after.risk) * 0.4) + after.future_money - before.future_money


static func unique(values: Array) -> Array:
	var result = []
	for value in values:
		if not result.has(value):
			result.push_back(value)
	return result


static func stat_field(name: String) -> String:
	return {"nb_projectiles": "projectiles", "max_range": "range", "piercing_dmg_reduction": "piercing_reduction", "bounce_dmg_reduction": "bounce_reduction"}.get(name, name)


static func counts(values: Array) -> Dictionary:
	var result = {}
	for value in values:
		result[value] = result.get(value, 0) + 1
	return result
