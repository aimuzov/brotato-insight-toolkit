extends Reference

const State = preload("choice_state.gd")
const Model = preload("choice_model.gd")
const EPSILON = 0.05
const MAX_POOL_EVALUATIONS = 48
const MAX_PURCHASE_STATES = 96
var _search_steps = 0


func plan(data: Dictionary, offers: Array, context: Dictionary, reroll: Dictionary = {}) -> Dictionary:
	var initial = State.new(data)
	var baseline = Model.evaluate(initial, context)
	var shadow = money_weight(data, context)
	var cards = []
	var sales = {}
	var best = {"value": 0.0, "actions": [], "spent": 0.0}
	for offer in offers:
		var action = {"kind": "buy", "item": offer, "cost": offer.get("price", 0.0)}
		var result = route(initial, [action], baseline, context, shadow)
		cards.push_back(result)
	for owned in (data.get("weapons", []) if context.get("mode", "shop") == "shop" else []):
		var uid = owned.get("uid", owned.id)
		var sale = {"kind": "sell", "uid": uid, "name": owned.get("name", owned.id), "value": owned.get("sale_value", 0.0)}
		var direct = route(initial, [sale], baseline, context, shadow)
		sales[uid] = direct
		for index in offers.size():
			var purchase = {"kind": "buy", "item": offers[index], "cost": offers[index].get("price", 0.0)}
			var replacement = route(initial, [sale, purchase], baseline, context, shadow)
			if replacement.value > cards[index].value + EPSILON:
				cards[index] = replacement
			if replacement.value > sales[uid].value + EPSILON:
				sales[uid] = replacement
	_search_steps = 0
	if context.get("mode", "shop") == "shop":
		_search_purchases(initial, offers, [], [], baseline, context, shadow, cards)
	for card in cards:
		if card.value > best.value:
			best = card
	var roll = estimate_reroll(initial, baseline, context, reroll, shadow)
	var can_roll = reroll.get("available", false) and data.get("cash", 0.0) >= reroll.get("price", 0.0)
	var roll_wins = can_roll and roll.reliable and roll.expected > best.value + max(2.0, abs(best.value) * 0.15)
	for card in cards:
		if card.ok and card.confidence == "low":
			roll_wins = false
			roll.reason = "Не все эффекты текущих вариантов оценены"
	var best_mandatory = -1
	var best_mandatory_value = -INF
	for index in cards.size():
		if cards[index].get("ok", false) and cards[index].value > best_mandatory_value:
			best_mandatory = index
			best_mandatory_value = cards[index].value
	for index in cards.size():
		var card = cards[index]
		if not card.ok:
			card["decision"] = card.get("reason", "Недоступно")
		elif card.confidence == "low":
			card["decision"] = "Нужна ручная проверка эффектов"
		elif roll_wins:
			card["decision"] = "Реролл выгоднее по оценке"
		elif card.value > EPSILON and abs(card.value - best.value) <= EPSILON:
			card["decision"] = "Купить по расчёту" if context.get("mode", "shop") == "shop" else "Выбрать по расчёту"
			if card.actions.size() > 1:
				card.decision = "Выгодная замена" if card.actions[0].kind == "sell" else "Выгодно вместе"
		elif context.get("mode", "shop") == "upgrade" and not roll_wins and best_mandatory >= 0:
			card["decision"] = "Лучший из доступных" if abs(card.value - best_mandatory_value) <= EPSILON else "Есть вариант выгоднее"
		elif card.value > EPSILON:
			card["decision"] = "Есть вариант выгоднее"
		else:
			card["decision"] = "Сохранить материалы" if data.get("currency_kind", "gold") == "gold" else "Сохранить детали"
	for uid in sales:
		var sale = sales[uid]
		if not sale.ok:
			sale["decision"] = sale.get("reason", "Продажа недоступна")
		elif sale.confidence == "low":
			sale["decision"] = "Продажа: неполный расчёт"
		elif sale.value > max(2.0, abs(sale.get("combat", 0.0)) * 0.15):
			sale["decision"] = "Продать ради замены" if sale.actions.size() > 1 else "Можно продать по расчёту"
		else:
			sale["decision"] = "Оставить оружие"
	return {"cards": cards, "sales": sales, "value": best.value, "actions": best.actions,
		"spent": best.get("spent", 0.0), "reroll": roll, "roll_wins": roll_wins}


func _search_purchases(initial, offers: Array, used: Array, actions: Array, baseline: Dictionary, context: Dictionary, shadow: float, cards: Array) -> void:
	for index in offers.size():
		if used.has(index) or _search_steps >= MAX_PURCHASE_STATES:
			continue
		_search_steps += 1
		var next_actions = actions.duplicate(true)
		next_actions.push_back({"kind": "buy", "item": offers[index], "cost": offers[index].get("price", 0.0)})
		var result = route(initial, next_actions, baseline, context, shadow)
		if not result.ok:
			continue
		var next_used = used.duplicate()
		next_used.push_back(index)
		for included in next_used:
			if result.value > cards[included].value + EPSILON:
				cards[included] = result.duplicate(true)
		_search_purchases(initial, offers, next_used, next_actions, baseline, context, shadow, cards)


func route(initial, actions: Array, baseline: Dictionary, context: Dictionary, shadow: float) -> Dictionary:
	var candidate = initial.fork()
	var spent = 0.0
	for action in actions:
		var applied = candidate._apply(action)
		if not applied.ok:
			return {"ok": false, "value": -INF, "actions": [], "reason": applied.reason, "confidence": "low"}
		spent += action.get("cost", 0.0)
	var after = Model.evaluate(candidate, context)
	var combat = Model.improvement(baseline, after, context)
	var money_delta = candidate.data.cash - initial.data.cash
	if not initial.data.currency_kind in ["gold", "hp"]:
		money_delta += candidate.data.currency - initial.data.currency
	var value = combat + money_delta * shadow
	var unknown = Model.unique(after.unknown + baseline.unknown)
	var uncertain = false
	for label in after.unknown_counts:
		uncertain = uncertain or after.unknown_counts[label] > baseline.unknown_counts.get(label, 0)
	if not baseline.unknown.empty():
		uncertain = uncertain or baseline.dps <= 0.1
		for action in actions:
			uncertain = uncertain or action.kind == "sell"
	var confidence = "low" if uncertain else ("high" if unknown.empty() and context.get("confidence", 0.0) >= 0.9 else "medium")
	var reasons = []
	if abs(after.dps - baseline.dps) >= 0.1:
		reasons.push_back("Урон %s/с" % signed(after.dps - baseline.dps))
	if abs(after.ehp / max(1.0, baseline.ehp) - 1.0) >= 0.01:
		reasons.push_back("Живучесть %s%%" % signed((after.ehp / max(1.0, baseline.ehp) - 1.0) * 100.0))
	if abs(after.future_money - baseline.future_money) >= 1.0:
		reasons.push_back("Доход за %d волн: %s" % [context.get("horizon", 3), signed(after.future_money - baseline.future_money)])
	if actions.size() > 1 and actions[0].kind == "sell":
		reasons.push_front("Продать %s, купить %s" % [actions[0].get("name", "оружие"), actions[1].item.get("name", "замену")])
	if actions.size() > 1 and actions[0].kind == "buy":
		var names = []
		for action in actions:
			names.push_back(action.item.get("name", "предмет"))
		reasons.push_front("Вместе: " + PoolStringArray(names).join(", "))
	if after.risk > baseline.risk + 0.1:
		reasons.push_back("Выше риск погибнуть от серии ударов")
	return {"ok": true, "value": value, "combat": combat, "actions": actions.duplicate(true), "spent": spent,
		"dps": after.dps - baseline.dps, "def": after.ehp / max(1.0, baseline.ehp) - 1.0,
		"base_dps": baseline.dps, "confidence": confidence, "unknown": unknown, "reasons": reasons,
		"partial": confidence == "low", "future_money": after.future_money - baseline.future_money}


func estimate_reroll(initial, baseline: Dictionary, context: Dictionary, options: Dictionary, shadow: float) -> Dictionary:
	var unavailable = {"expected": 0.0, "reliable": false, "samples": 0, "reason": "Нет данных о пуле"}
	if not options.get("available", false) or options.get("draws", 0) <= 0:
		return unavailable
	var outcomes = options.get("outcomes", []).duplicate(true)
	var pool = options.get("pool", [])
	var rolled = initial.fork()
	var price = float(options.get("price", 0.0))
	if rolled.data.cash < price:
		unavailable.reason = "Не хватает материалов на реролл"
		return unavailable
	rolled.data.cash -= price
	if rolled.data.currency_kind == "gold":
		rolled.data.currency -= price
	var unknown_weight = 0.0
	var total_weight = 0.0
	for index in min(pool.size(), MAX_POOL_EVALUATIONS):
		var entry = pool[index]
		var result = route(rolled, [{"kind": "buy", "item": entry.item, "cost": entry.item.get("price", 0.0)}], baseline, context, shadow)
		var weight = max(0.0, float(entry.get("weight", 1.0)))
		total_weight += weight
		if result.get("confidence", "low") == "low":
			unknown_weight += weight
		outcomes.push_back({"value": max(0.0, result.value) if result.ok else 0.0, "weight": weight})
	if outcomes.empty():
		return unavailable
	var result = reroll_value(outcomes, options.draws, price, shadow)
	result["samples"] = outcomes.size()
	result["reliable"] = options.get("coverage", 1.0) >= 0.8 and (total_weight <= 0.0 or unknown_weight / total_weight <= 0.1)
	result["reason"] = "Ожидаемая польза реролла с учётом цены" if result.reliable else "Пул или эффекты оценены не полностью"
	return result


func reroll_value(outcomes: Array, draws: int, price: float, shadow: float) -> Dictionary:
	var ordered = outcomes.duplicate(true)
	ordered.sort_custom(self, "_less_outcome")
	var total = 0.0
	for outcome in ordered:
		total += max(0.0, outcome.get("weight", 0.0))
	if total <= 0.0 or draws <= 0:
		return {"expected": -price * shadow}
	var cumulative = 0.0
	var previous_cdf = 0.0
	var expected = 0.0
	for outcome in ordered:
		cumulative += max(0.0, outcome.weight) / total
		var cdf = pow(clamp(cumulative, 0.0, 1.0), draws)
		expected += max(0.0, outcome.value) * (cdf - previous_cdf)
		previous_cdf = cdf
	return {"expected": expected - price * shadow}


func _less_outcome(left: Dictionary, right: Dictionary) -> bool:
	return left.value < right.value


static func money_weight(data: Dictionary, context: Dictionary) -> float:
	return clamp(1.0 + max(0.0, context.get("income", 80.0) * 0.25 - data.get("cash", 0.0)) / max(20.0, context.get("income", 80.0)), 1.0, 1.25)


static func signed(value: float) -> String:
	return ("+" if value > 0 else "") + str(stepify(value, 0.1))
