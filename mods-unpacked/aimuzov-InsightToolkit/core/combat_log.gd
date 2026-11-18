extends Reference

# Журнал боя за волну по каждому игроку и типу врага:
# сколько урона игрок нанёс этим врагам, сколько получил от них, сколько убил.
# Урон считаем снятым HP, без оверкилла, чтобы цифры складывались в HP врагов.

const MAX_PLAYERS = 4
const Settings = preload("res://mods-unpacked/aimuzov-InsightToolkit/core/settings.gd")
const DamageDisplay = preload("res://mods-unpacked/aimuzov-InsightToolkit/core/damage_display.gd")

# players[i][enemy_key] = {icon, dealt, taken, kills}
var players = []
var metrics = []
var weapon_damage = []
var duration = 0.0

var _hp_before = {}
var _hp_last = {}


func _init() -> void:
	for i in MAX_PLAYERS:
		players.push_back({})
		weapon_damage.push_back({})
		metrics.push_back({"hits": 0, "taken": 0.0, "max_hit": 0.0, "healed": 0.0, "kills": 0, "dealt": 0.0, "hp": 0.0, "gold_start": 0, "income": 0.0, "armor": 1.0, "dodge": 0.0})


func track_enemy(enemy: Node, owner: Object) -> void:
	if not enemy.is_connected("health_updated", owner, "_dc_on_enemy_health_updated"):
		enemy.connect("health_updated", owner, "_dc_on_enemy_health_updated")
		enemy.connect("took_damage", owner, "_dc_on_enemy_took_damage")
		enemy.connect("died", owner, "_dc_on_enemy_died")
	_hp_last[enemy.get_instance_id()] = enemy.current_stats.health


func track_player(player: Node, owner: Object) -> void:
	player.connect("took_damage", owner, "_dc_on_player_took_damage")
	player.connect("health_updated", owner, "_dc_on_player_health_updated")
	metrics[player.player_index].hp = player.current_stats.health
	metrics[player.player_index].gold_start = RunData.get_player_gold(player.player_index)
	metrics[player.player_index].armor = RunData.get_armor_coef(int(Utils.get_stat(Keys.stat_armor_hash, player.player_index)))
	metrics[player.player_index].dodge = clamp(Utils.get_capped_stat(Keys.stat_dodge_hash, player.player_index) / 100.0, 0.0, 0.9)


# health_updated приходит раньше took_damage, поэтому запоминаем HP до удара
func on_enemy_health_updated(unit: Node, current_health: int) -> void:
	var id = unit.get_instance_id()
	var last = _hp_last.get(id, current_health)
	_hp_before[id] = last
	_hp_last[id] = current_health


func on_enemy_took_damage(unit: Node, value: int, args) -> void:
	var player_index = args.from_player_index if args != null else -1
	if player_index < 0 or player_index >= MAX_PLAYERS:
		return
	var id = unit.get_instance_id()
	var before = _hp_before.get(id, unit.current_stats.health + value)
	var dealt = clamp(before - unit.current_stats.health, 0, value)
	metrics[player_index].dealt += dealt
	if Settings.enabled("creep_stats"):
		_entry(player_index, unit).dealt += dealt


func on_enemy_died(unit: Node, args) -> void:
	var player_index = args.killed_by_player_index if args != null and args.get("killed_by_player_index") != null else -1
	if player_index >= 0 and player_index < MAX_PLAYERS:
		metrics[player_index].kills += 1
		if Settings.enabled("creep_stats"):
			_entry(player_index, unit).kills += 1


func on_player_health_updated(player: Node, health: int) -> void:
	var record = metrics[player.player_index]
	if health > record.hp:
		record.healed += health - record.hp
	else:
		record.taken += record.hp - health
		record.max_hit = max(record.max_hit, record.hp - health)
		if record.hp > health:
			record.hits += 1
	record.hp = health


func finish(seconds: float) -> void:
	duration = seconds
	for index in RunData.get_player_count():
		metrics[index].income = max(0, RunData.get_player_gold(index) - metrics[index].gold_start)
		weapon_damage[index].clear()
		for group in DamageDisplay.weapons(RunData.get_player_weapons(index)):
			weapon_damage[index][group.key] = DamageDisplay.damage(group.members)


# Источник урона по игроку — враг из hitbox.from (сам враг или хозяин его снаряда)
func on_player_took_damage(player: Node, value: int, args) -> void:
	if not Settings.enabled("creep_stats"):
		return
	if value <= 0 or args == null or args.hitbox == null:
		return
	var source = args.hitbox.from
	if not is_instance_valid(source) or source.get("stats") == null:
		return
	_entry(player.player_index, source).taken += value


func _entry(player_index: int, enemy: Node) -> Dictionary:
	var key = enemy.filename if enemy.filename != "" else enemy.name
	var table = players[player_index]
	if not table.has(key):
		var icon = enemy.stats.icon if enemy.stats != null else null
		table[key] = {"icon": icon, "dealt": 0.0, "taken": 0.0, "kills": 0}
	return table[key]


# Строки для панели игрока: самые значимые типы врагов первыми
func top_rows(player_index: int, limit: int) -> Array:
	var rows = players[player_index].values()
	rows.sort_custom(self, "_by_weight")
	return rows.slice(0, limit - 1) if rows.size() > limit else rows


func _by_weight(a: Dictionary, b: Dictionary) -> bool:
	return a.dealt + a.taken * 5.0 > b.dealt + b.taken * 5.0
