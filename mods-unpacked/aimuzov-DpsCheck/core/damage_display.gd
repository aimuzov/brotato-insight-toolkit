extends Reference


static func number(value: float) -> String:
	var formatted = parts(value)
	return formatted.digits + formatted.suffix


static func parts(value: float) -> Dictionary:
	var amount = max(0.0, value)
	var suffixes = ["", "k", "kk", "kkk"]
	var index = 0
	while amount >= 1000.0 and index < suffixes.size() - 1:
		amount /= 1000.0
		index += 1
	amount = round(amount) if index == 0 else stepify(amount, 0.1)
	if amount >= 1000.0 and index > 0 and index < suffixes.size() - 1:
		amount /= 1000.0
		index += 1
	return {"digits": str(amount), "suffix": suffixes[index]}


static func family(weapon: Resource) -> String:
	var id = weapon.get("weapon_id")
	if id != null and str(id) != "":
		return str(id)
	return weapon.name if weapon.name != "" else weapon.my_id


static func weapons(resources: Array) -> Array:
	var groups = []
	var positions = {}
	for weapon in resources:
		var key = family(weapon)
		if not positions.has(key):
			positions[key] = groups.size()
			groups.push_back({"key": key, "data": weapon, "members": []})
		var group = groups[positions[key]]
		group.members.push_back(weapon)
		if weapon.tier > group.data.tier:
			group.data = weapon
	return groups


static func damage(members: Array) -> float:
	var total = 0.0
	for weapon in members:
		total += float(weapon.dmg_dealt_last_wave)
	return total
