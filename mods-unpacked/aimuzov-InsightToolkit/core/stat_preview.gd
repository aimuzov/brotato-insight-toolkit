extends Reference

const DcTranslations = preload("res://mods-unpacked/aimuzov-InsightToolkit/core/translations.gd")
const Catalog = preload("choice_catalog.gd")
const State = preload("choice_state.gd")
const Dependencies = preload("stat_dependencies.gd")


static func totals(item_data: Resource, player_index: int, owned: bool, price: float = 0.0) -> Dictionary:
	var deltas = {}
	if item_data == null or player_index < 0 or player_index >= RunData.get_player_count():
		return deltas
	if item_data.my_id.begins_with("character_") or item_data.my_id.begins_with("difficulty_") or RunData.get_player_character(player_index) == null:
		return deltas
	for effect in item_data.effects:
		if not _is_stat(effect):
			continue
		deltas[effect.key_hash] = deltas.get(effect.key_hash, 0.0) + effect.get_applied_value(player_index)
	var result = {}
	if owned:
		for key in deltas:
			result[key] = Utils.get_stat(key, player_index)
		return result
	var catalog = Catalog.new()
	var data = cached_data(catalog, player_index)
	var definition = catalog.item(item_data)
	for key in catalog._sets:
		data.sets[key] = catalog._sets[key].duplicate(true)
	var before = State.new(data)
	var after = before.fork()
	var applied = after.apply({"kind": "buy", "item": definition, "cost": price})
	var direct = {}
	for key in deltas:
		var name = Catalog.key_name(key)
		direct[name] = deltas[key] * RunData.get_stat_gain(key, player_index)
		result[key] = after.stat(name, {"preview": true}) if applied.ok else Utils.get_stat(key, player_index)
	result["related"] = Dependencies.project(before, after, direct, {"preview": true}) if applied.ok else {"rows": [], "notes": []}
	if applied.ok and data.currency_kind == "hp" and price > 0:
		for row in result.related.rows:
			if row.key == "stat_max_hp":
				row.sources.push_back("Стоимость покупки")
	result["preview_reason"] = "" if applied.ok else applied.reason
	result["preview_unknown"] = definition.unknown
	return result


static func cached_data(catalog, player_index: int) -> Dictionary:
	var player = RunData.players_data[player_index]
	var ids = []
	for object in player.items + player.weapons:
		ids.push_back(object.get_instance_id())
	var fingerprint = hash(str([player.effects, TempStats.player_stats[player_index], ids, player.gold, player.current_level]))
	var key = "dc_stat_preview_%d" % player_index
	if Engine.has_meta(key):
		var cached = Engine.get_meta(key)
		if cached.fingerprint == fingerprint:
			catalog._player = player_index
			return cached.data.duplicate(true)
	var data = catalog.capture(player_index)
	Engine.set_meta(key, {"fingerprint": fingerprint, "data": data})
	return data.duplicate(true)


static func append_related(description: Node, values: Dictionary, colored: bool) -> void:
	var effects = description.get_effects()
	for child in effects.get_children():
		if child.name.begins_with("DcStatImpact"):
			effects.remove_child(child)
			child.queue_free()
	var related = values.get("related", {"rows": [], "notes": []})
	for row in related.rows:
		var label = stat_label(row.key)
		var delta = ("+" if row.delta > 0 else "") + str(stepify(row.delta, 0.1)) + label.suffix
		if colored:
			var color = ProgressData.settings.color_positive if row.delta > 0 else ProgressData.settings.color_negative
			delta = "[color=#%s]%s[/color]" % [color, delta]
		var text = "%s%s %s (%s%s)" % ["Дополнительно: " if row.additional else "", label.name, delta, str(stepify(row.after, 0.1)), label.suffix]
		if not row.sources.empty():
			text += ": " + PoolStringArray(row.sources).join(", ")
		append_line(description, text, ItemService.get_stat_small_icon(Keys.generate_hash(row.key)))
	for note in related.notes:
		var name = stat_label(note.from).name
		var source = PoolStringArray(note.sources).join(", ") if not note.sources.empty() else stat_label(note.to).name
		var text = ""
		match note.reason:
			"permanent_only":
				text = "%s: учитывается только постоянный показатель «%s»" % [source, name]
			"no_linked_scaling":
				text = "%s: бонусы других связей не учитываются" % source
			"threshold":
				text = "%s: прибавка к «%s» ещё не достигла порога" % [source, name]
		append_line(description, text, null)
	if values.get("preview_reason", "") != "":
		append_line(description, "Связанные изменения: " + values.preview_reason, null)
	if not values.get("preview_unknown", []).empty():
		append_line(description, "Неполный предпросмотр: " + PoolStringArray(values.preview_unknown).join(", "), null)


static func append_line(description: Node, text: String, icon) -> void:
	var line = description.effect_line.instance()
	line.name = "DcStatImpact" + str(description.get_effects().get_child_count())
	description.get_effects().add_child(line)
	line._display_special_text(text, icon)
	description.get_effects().show()


static func stat_label(key: String) -> Dictionary:
	var text = DcTranslations.text(key.to_upper())
	return {"name": text.trim_prefix("% ").strip_edges(), "suffix": "%" if text.find("%") >= 0 else ""}


static func format_line(line: Node, player_index: int, values: Dictionary, colored: bool) -> void:
	var effect = line.effect
	if not _is_stat(effect) or not values.has(effect.key_hash):
		return
	var icon = ItemService.get_stat_small_icon(effect.key_hash)
	if icon == null:
		return
	var value = effect.get_applied_value(player_index)
	var name = DcTranslations.text(effect.key.to_upper())
	var suffix = "%" if name.find("%") >= 0 else ""
	name = name.trim_prefix("% ").strip_edges()
	var change = ("+" if value > 0 else "") + str(value) + suffix
	if colored:
		var color = _color(effect, value)
		change = "[color=#%s]%s[/color]" % [color.to_html(false), change]
	line.effect_icon.texture = icon
	line.text_descr.bbcode_text = "%s %s (%d%s)" % [name, change, int(values[effect.key_hash]), suffix]


static func _is_stat(effect: Resource) -> bool:
	return effect != null and effect.get_script() == Effect and effect.storage_method == Effect.StorageMethod.SUM and Utils.is_stat_key(effect.key_hash)


static func _color(effect: Resource, value: float) -> Color:
	if effect.added_by_mutation:
		return Utils.MUTANT_COLOR
	var sign_value = effect.get_sign(effect.effect_sign, value)
	if sign_value == Effect.Sign.POSITIVE:
		return Color(ProgressData.settings.color_positive)
	if sign_value == Effect.Sign.NEGATIVE:
		return Color(ProgressData.settings.color_negative)
	return Color.white
