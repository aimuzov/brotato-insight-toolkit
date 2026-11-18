extends Node

var State
var Model
var Planner
var checks = 0
var failures = 0


func check(actual, expected, label):
	checks += 1
	if actual != expected:
		failures += 1
		printerr("FAIL ", label, ": ", actual, " expected ", expected)


func near(actual, expected, label):
	check(abs(actual - expected) < 0.001, true, label)


func effect(key, value, kind = "sum"):
	return {"kind": kind, "key": key, "value": value}


func weapon(uid = "gun", damage = 10.0):
	return {"id": uid, "uid": uid, "family": uid, "name": uid, "kind": "weapon", "tier": 0,
		"effects": [], "sets": [], "flavor": "plain", "value": 20,
		"stats": {"damage": damage, "cooldown": 60.0, "accuracy": 1.0, "crit_chance": 0.0,
			"crit_damage": 2.0, "range": 300.0, "ranged": true, "projectiles": 1,
			"scaling": [["stat_ranged_damage", 1.0]], "animation": 0.0}}


func item(uid, effects, price = 10):
	return {"id": uid, "uid": uid, "name": uid, "kind": "item", "tier": 0,
		"effects": effects, "sets": [], "price": price, "value": price, "max_nb": -1}


func build():
	return {"effects": {"stat_max_hp": 30.0, "weapon_slot": 6.0},
		"weapons": [weapon()], "items": [], "sets": {}, "applied_sets": [],
		"derived": {}, "cash": 80.0, "currency": 80.0, "currency_kind": "gold",
		"wave": 5, "last_wave": 20, "level": 5, "unknown": []}


func context():
	return {"duration": 60.0, "density": 3.0, "boss_fraction": 0.1, "required_dps": 10.0,
		"income": 80.0, "horizon": 3, "hit_rate": 0.15, "mean_hit": 4.0,
		"max_hit": 8.0, "confidence": 0.8, "currency_kind": "gold"}


func _ready():
	call_deferred("run")


func run():
	State = load("res://core/choice_state.gd")
	Model = load("res://core/choice_model.gd")
	Planner = load("res://core/choice_planner.gd")
	if State == null or Model == null or Planner == null:
		check(false, true, "choice engine exists")
		get_tree().quit(1)
		return
	var original = build()
	var state = State.new(original)
	var hp = item("hp", [effect("stat_max_hp", 10)])
	check(state.apply({"kind": "buy", "item": hp, "cost": 10}).ok, true, "buy")
	near(state.stat("stat_max_hp"), 40, "HP applied")
	near(original.effects.stat_max_hp, 30, "original immutable")
	near(state.data.cash, 70, "money spent on copy")
	state = State.new(build())
	state.data.effects.gain_stat_ranged_damage = 100
	state.apply({"kind": "buy", "item": item("ranged", [effect("stat_ranged_damage", 3)]), "cost": 0})
	near(state.stat("stat_ranged_damage"), 6, "character stat multiplier")
	state.data.effects.stat_links = [["stat_percent_damage", 2, "stat_max_hp", 5, true]]
	near(state.stat("stat_percent_damage"), 12, "linked HP scaling")
	state.data.effects.hp_cap = 20
	near(state.stat("stat_max_hp"), 20, "character HP cap")
	state = State.new(build())
	check(state.apply({"kind": "buy", "item": hp, "cost": 100}).ok, false, "no unaffordable purchase")
	near(state.data.cash, 80, "failed purchase leaves state unchanged")
	var limited = item("limited", [], 5)
	limited.max_nb = 1
	state.apply({"kind": "buy", "item": limited, "cost": 5})
	check(state.apply({"kind": "buy", "item": limited, "cost": 5}).ok, false, "limited item cap")
	var demon = build()
	demon.currency_kind = "hp"
	demon.currency = 30
	state = State.new(demon)
	state.apply({"kind": "buy", "item": item("damage", [effect("stat_ranged_damage", 3)]), "cost": 5})
	near(state.stat("stat_max_hp"), 25, "HP shop spends health")
	near(state.data.cash, 80, "HP shop preserves materials")
	var set_build = build()
	set_build.effects.weapon_slot = 2
	set_build.effects.stat_ranged_damage = 5
	set_build.sets = {"ranged": [[effect("stat_ranged_damage", 5)]]}
	set_build.applied_sets = [effect("stat_ranged_damage", 5)]
	set_build.weapons = [weapon("a"), weapon("b")]
	for w in set_build.weapons:
		w.sets = ["ranged"]
	state = State.new(set_build)
	state.apply({"kind": "sell", "uid": "a", "value": 5})
	near(state.stat("stat_ranged_damage"), 0, "selling breaks weapon class bonus")
	check(set_build.weapons.size(), 2, "sale does not mutate source inventory")
	var merge_build = build()
	merge_build.effects.weapon_slot = 1
	var next_weapon = weapon("gun2", 18)
	next_weapon.tier = 1
	merge_build.weapons[0].upgrade = next_weapon
	state = State.new(merge_build)
	check(state.apply({"kind": "buy", "item": merge_build.weapons[0], "cost": 10}).ok, true, "combine at full slots")
	check(state.data.weapons.size(), 1, "combined slot count")
	near(state.data.weapons[0].stats.damage, 18, "combined stats")
	var unique_build = merge_build.duplicate(true)
	unique_build.effects.weapon_slot = 6
	unique_build.effects.no_duplicate_weapons = 1
	unique_build.weapons[0].calibration = 0.2
	state = State.new(unique_build)
	check(state.apply({"kind": "buy", "item": unique_build.weapons[0], "cost": 0}).ok, true, "unique weapon combines despite free slots")
	check(state.data.weapons.size(), 1, "unique weapon not duplicated")
	near(state.data.weapons[0].get("calibration", 1.0), 0.2, "combine inherits calibration")
	var type_limit = build()
	type_limit.effects.max_ranged_weapons = 1
	state = State.new(type_limit)
	check(state.apply({"kind": "buy", "item": weapon("other"), "cost": 0}).ok, false, "per-type slot limit")
	var linked_build = build()
	linked_build.weapons = [weapon("one"), weapon("two")]
	linked_build.weapons[1].family = "one"
	linked_build.effects.stat_links = [["stat_percent_damage", 10, "duplicate_item", 1, true]]
	near(State.new(linked_build).stat("stat_percent_damage"), 10, "duplicate weapons count in stat links")
	linked_build.items = [item("character_test", []), item("item_tumor", []), item("item_real", [])]
	near(State.new(linked_build).scaled_value("different_item", {}), 1, "character and tumor not counted as different items")
	linked_build.items = [item("pet_item", [])]
	linked_build.items[0].sources = [{"kind": "structure", "pet": true}, {"kind": "proc"}]
	near(State.new(linked_build).scaled_value("pet", {}), 1, "native pet key")
	near(State.new(linked_build).scaled_value("structure", {}), 1, "damage procs are not structures")
	var stats = Model.evaluate(State.new(build()), context())
	check(stats.dps > 0, true, "weapon DPS")
	var richer = build()
	richer.effects.stat_ranged_damage = 10
	check(Model.evaluate(State.new(richer), context()).dps > stats.dps, true, "ranged scaling")
	var projectile_bonus = build()
	projectile_bonus.effects.weapon_type_bonus = [[1, "nb_projectiles", 1]]
	check(Model.evaluate(State.new(projectile_bonus), context()).dps > stats.dps * 1.5, true, "native projectile bonus field")
	projectile_bonus.effects.weapon_type_bonus = [[1, "max_range", 200]]
	check(Model.evaluate(State.new(projectile_bonus), context()).dps > stats.dps, true, "native range bonus field")
	var piercing = build()
	piercing.weapons[0].stats.piercing = 2
	check(Model.evaluate(State.new(piercing), context()).dps > stats.dps, true, "piercing helps dense wave")
	var engineering = build()
	engineering.weapons = []
	engineering.effects.stat_engineering = 10
	engineering.sources = [{"kind": "structure", "count": 1, "stats": {
		"damage": 5.0, "cooldown": 60.0, "scaling": [["stat_engineering", 1.0]], "projectiles": 1}}]
	check(Model.evaluate(State.new(engineering), context()).dps > 0, true, "engineering sources")
	var engineer_base = Model.evaluate(State.new(engineering), context())
	engineering.effects.stat_lifesteal = 100
	near(Model.evaluate(State.new(engineering), context()).healing, engineer_base.healing, "turrets do not receive player lifesteal")
	engineering.effects.weapon_scaling_stats = [["stat_ranged_damage", 100]]
	engineering.effects.stat_ranged_damage = 100
	near(Model.evaluate(State.new(engineering), context()).dps, engineer_base.dps, "normal turrets ignore weapon scaling additions")
	var burn = build()
	burn.weapons[0].stats.burn = {"damage": 5.0, "chance": 1.0, "duration": 3.0, "scaling": []}
	check(Model.evaluate(State.new(burn), context()).dps > stats.dps, true, "burning contribution")
	var healing = build()
	healing.effects.stat_hp_regeneration = 1000
	var healed = Model.evaluate(State.new(healing), context())
	check(healed.healing <= healed.incoming + 0.001, true, "no unlimited overhealing")
	var low_hp = build()
	low_hp.effects.stat_max_hp = 3
	check(Model.evaluate(State.new(low_hp), context()).risk > stats.risk, true, "burst risk")
	var harvest = build()
	harvest.effects.stat_harvesting = 10
	check(Model.evaluate(State.new(harvest), context()).future_money > stats.future_money, true, "harvesting income")
	var final_wave = context()
	final_wave.horizon = 0
	near(Model.evaluate(State.new(harvest), final_wave).future_money, 0, "no future harvesting at run end")
	var stronger_enemies = build()
	stronger_enemies.effects.enemy_health = 50
	check(Model.improvement(stats, Model.evaluate(State.new(stronger_enemies), context()), context()) < 0, true, "enemy HP penalty changes value")
	stronger_enemies.effects.enemy_health = 0
	stronger_enemies.effects.enemy_damage = 50
	check(Model.evaluate(State.new(stronger_enemies), context()).risk > stats.risk, true, "enemy damage penalty changes risk")
	var expensive = item("expensive", [effect("stat_ranged_damage", 2)], 70)
	var cheap = item("cheap", [effect("stat_ranged_damage", 2)], 5)
	var planner = Planner.new()
	var plan = planner.plan(build(), [expensive, cheap], context(), {})
	check(plan.cards[1].value > plan.cards[0].value, true, "value includes price")
	var tied = planner.plan(build(), [cheap, cheap.duplicate(true)], context(), {})
	check(tied.cards[0].decision, tied.cards[1].decision, "ties treated equally")
	var unknown = item("unknown", [{"kind": "unknown", "label": "special mechanic"}], 5)
	var uncertain = planner.plan(build(), [unknown], context(), {})
	check(uncertain.cards[0].confidence, "low", "unknown effect reduces confidence")
	check(not uncertain.cards[0].decision in ["Пропустить", "Продать", "Разобрать"], true, "no decisive negative advice for unknown effect")
	var unknown_roll = planner.plan(build(), [unknown], context(), {"available": true, "price": 0.0, "draws": 4,
		"outcomes": [{"value": 100.0, "weight": 1.0}], "coverage": 1.0})
	check(unknown_roll.roll_wins, false, "unknown current option prevents confident reroll")
	var owns_unknown = build()
	owns_unknown.items = [unknown.duplicate(true)]
	var second_unknown = planner.plan(owns_unknown,[unknown],context(),{})
	check(second_unknown.cards[0].confidence,"low","another copy of unknown effect remains uncertain")
	seed(7321)
	var expected_rng = randf()
	seed(7321)
	planner.plan(build(), [cheap], context(), {})
	near(randf(), expected_rng, "planner never consumes RNG")
	var outcomes = [{"value": 0.0, "weight": 0.5}, {"value": 20.0, "weight": 0.5}]
	var reroll = planner.reroll_value(outcomes, 2, 3.0, 1.0)
	near(reroll.expected, 12.0, "expected maximum less reroll price")
	check(planner.reroll_value(outcomes, 2, 30.0, 1.0).expected < 0, true, "expensive reroll rejected")
	near(planner.reroll_value(outcomes, 2, 0.0, 1.0).expected, 15.0, "free reroll")
	var free_offer = item("free", [effect("stat_ranged_damage", 2)], 0)
	var initial = State.new(build())
	var baseline = Model.evaluate(initial, context())
	var gain = planner.route(initial, [{"kind": "buy", "item": free_offer, "cost": 0}], baseline, context(), 1.0).value
	var actual_roll = planner.estimate_reroll(initial, baseline, context(), {"available": true, "price": 10.0,
		"draws": 1, "coverage": 1.0, "pool": [{"item": free_offer, "weight": 1.0}]}, 1.0)
	near(actual_roll.expected, gain - 10.0, "full reroll estimator pays the reroll cost")
	var upgrade_context = context()
	upgrade_context.mode = "upgrade"
	check(planner.plan(build(), [free_offer, free_offer.duplicate(true)], upgrade_context, {}).actions.size(), 1, "one upgrade per choice")
	var pair = build()
	pair.currency = 10
	pair.cash = 10
	var left = item("left", [effect("stat_ranged_damage", 2)], 6)
	var right = item("right", [effect("stat_max_hp", 5)], 6)
	var pair_plan = planner.plan(pair, [left, right], context(), {})
	check(pair_plan.spent <= 10.0, true, "purchase plan respects total budget")
	var bundle = []
	for i in 4:
		bundle.push_back(item("bundle%d" % i, [effect("stat_ranged_damage", 2)], 1))
	check(planner.plan(build(), bundle, context(), {}).actions.size(), 4, "all four profitable purchases considered")
	var replace = build()
	replace.effects.weapon_slot = 1
	replace.cash = 5
	replace.currency = 5
	var better = weapon("better", 40)
	better.price = 10
	better.sale_value = 5
	replace.weapons[0].sale_value = 5
	var replace_plan = planner.plan(replace, [better], context(), {})
	check(replace_plan.cards[0].actions.size() >= 2, true, "sell then buy replacement")
	check(replace_plan.cards[0].actions[0].kind, "sell", "replacement sale first")
	var Dependencies = load("res://core/stat_dependencies.gd")
	if Dependencies == null:
		check(false, true, "stat dependency preview exists")
		get_tree().quit(1)
		return
	var links = build()
	links.effects.stat_crit_chance = 10
	links.effects.stat_luck = 20
	links.effects.stat_links = [["stat_luck", 2, "stat_crit_chance", 1, false], ["stat_percent_damage", 1, "stat_luck", 10, true]]
	links.link_sources = [{"from": "stat_crit_chance", "to": "stat_luck", "name": "Монетка"}, {"from": "stat_luck", "to": "stat_percent_damage", "name": "Жемчужина"}]
	var before_links = State.new(links)
	var after_links = before_links.fork()
	after_links.apply({"kind": "buy", "item": item("crit", [effect("stat_crit_chance", 5)]), "cost": 0})
	near(after_links.stat("stat_luck", {"preview": true}), 50, "coin luck from crit chance")
	near(after_links.stat("stat_percent_damage", {"preview": true}), 2, "pearl excludes linked coin luck")
	var dependency = Dependencies.project(before_links, after_links, {"stat_crit_chance": 5}, {"preview": true})
	check(dependency.rows.size(), 1, "only actual indirect change shown")
	check(dependency.rows[0].key, "stat_luck", "luck is secondary change")
	near(dependency.rows[0].delta, 10, "luck delta shown once")
	check(dependency.notes.size() > 0, true, "stopped permanent-only chain explained")
	after_links = before_links.fork()
	after_links.apply({"kind": "buy", "item": item("luck", [effect("stat_luck", 10)]), "cost": 0})
	near(after_links.stat("stat_percent_damage", {"preview": true}), 3, "permanent luck affects pearl")
	links.temporary = {"stat_luck": 10, "stat_crit_chance": 2}
	near(State.new(links).stat("stat_luck", {"preview": true}), 54, "temporary crit feeds non-permanent coin link")
	near(State.new(links).stat("stat_percent_damage", {"preview": true}), 2, "temporary luck excluded from permanent pearl link")
	var snowball = build()
	snowball.effects.gain_stat_for_equipped_item_with_stat = [["stat_percent_damage", 2, "stat_max_hp", 0]]
	state = State.new(snowball)
	state.apply({"kind": "buy", "item": item("hp_item", [effect("stat_max_hp", 3)]), "cost": 0})
	near(state.stat("stat_percent_damage"), 2, "item-stat acquisition triggers linked permanent bonus once")
	var hp_upgrade = item("hp_upgrade", [effect("stat_max_hp", 3)])
	hp_upgrade.kind = "upgrade"
	state = State.new(snowball)
	state.apply({"kind": "buy", "item": hp_upgrade, "cost": 0})
	near(state.stat("stat_percent_damage"), 0, "level upgrade does not trigger item-only bonus")
	var large = build()
	for index in 100:
		large.items.push_back(item("owned%d" % index, [effect("stat_ranged_damage", 1)]))
	var started = OS.get_ticks_usec()
	var large_plan = planner.plan(large, bundle, context(), {})
	check(large_plan.actions.size(),4,"large inventory plan")
	print("Large inventory planning: ", (OS.get_ticks_usec()-started)/1000.0, " ms")
	print("Choice engine: ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)
