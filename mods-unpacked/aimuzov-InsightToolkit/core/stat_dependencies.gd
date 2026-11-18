extends Reference


static func project(before, after, direct: Dictionary, context: Dictionary) -> Dictionary:
	var keys = {}
	for state in [before, after]:
		for key in state.data.effects:
			if key.begins_with("stat_") and (state.data.effects[key] is int or state.data.effects[key] is float):
				keys[key] = true
		for link in state.data.effects.get("stat_links", []):
			if link.size() >= 5:
				keys[link[0]] = true
	var rows = []
	var notes = []
	for key in keys:
		var previous = before.stat(key, context)
		var next = after.stat(key, context)
		var indirect = next - previous - float(direct.get(key, 0.0))
		if abs(indirect) < 0.001:
			continue
		var sources = []
		for source in after.data.link_sources:
			if source.to == key and affected(before, after, source.from, key, context) and not sources.has(source.name):
				sources.push_back(source.name)
		for gain in after.data.fired_gains:
			if gain.to == key:
				for name in gain.sources:
					if not sources.has(name):
						sources.push_back(name)
		rows.push_back({"key": key, "delta": indirect, "before": previous, "after": next, "sources": sources, "additional": direct.has(key)})
	for link in after.data.effects.get("stat_links", []):
		if link.size() < 5 or float(link[3]) == 0.0 or float(link[1]) == 0.0:
			continue
		var from = str(link[2])
		var to = str(link[0])
		var raw_before = before.scaled_value(from, context, bool(link[4]))
		var raw_after = after.scaled_value(from, context, bool(link[4]))
		var changed = abs(after.stat(from, context) - before.stat(from, context)) >= 0.001 or abs(raw_after - raw_before) >= 0.001
		if not changed:
			continue
		var reason = ""
		if abs(raw_after - raw_before) < 0.001:
			reason = "permanent_only" if bool(link[4]) else "no_linked_scaling"
		elif int(float(link[1]) * raw_after / float(link[3])) == int(float(link[1]) * raw_before / float(link[3])):
			reason = "threshold"
		if reason == "":
			continue
		var sources = []
		for source in after.data.link_sources:
			if source.from == from and source.to == to and not sources.has(source.name):
				sources.push_back(source.name)
		var note = {"from": from, "to": to, "reason": reason, "per": link[3], "sources": sources}
		var found = false
		for existing in notes:
			found = found or str(existing) == str(note)
		if not found:
			notes.push_back(note)
	return {"rows": rows, "notes": notes}


static func affected(before, after, from: String, to: String, context: Dictionary) -> bool:
	var signatures = {}
	for state in [before, after]:
		for link in state.data.effects.get("stat_links", []):
			if link.size() >= 5 and link[2] == from and link[0] == to and float(link[3]) != 0:
				signatures[str(link)] = link
	for signature in signatures:
		var link = signatures[signature]
		var values = []
		for state in [before, after]:
			var count = 0
			for existing in state.data.effects.get("stat_links", []):
				if str(existing) == signature:
					count += 1
			values.push_back(count * int(float(link[1]) * state.scaled_value(from, context, bool(link[4])) / float(link[3])) * (1.0 + state.number("gain_" + to) / 100.0))
		if abs(values[1] - values[0]) >= 0.001:
			return true
	return false
