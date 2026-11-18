extends Node2D

# Круги дальности атаки вокруг персонажа: по одному на каждую разную дальность оружия.
# Радиус как у самого оружия: Weapon.get_max_range() = max_range + 50.

const SETTINGS = "res://mods-unpacked/aimuzov-InsightToolkit/core/settings.gd"
const COLOR = Color(1, 1, 1, 0.09)
const WIDTH = 1.0
# Дальности ближе этого шага рисуем одним кругом, чтобы не было «ряби»
const MERGE_STEP = 15.0

var _player
var _settings
var _radii = []


func _init(player: Node) -> void:
	_player = player
	show_behind_parent = true


func _ready() -> void:
	_settings = load(SETTINGS)


func _process(_delta: float) -> void:
	var shown = _settings.enabled("range_area") and is_instance_valid(_player) and not _player.dead
	if visible != shown:
		visible = shown
	if not shown:
		return
	var radii = _collect_radii()
	if radii != _radii:
		_radii = radii
		update()


func _collect_radii() -> Array:
	var radii = []
	for weapon in _player.current_weapons:
		if not is_instance_valid(weapon):
			continue
		var radius = float(weapon.get_max_range())
		var merged = false
		for existing in radii:
			if abs(existing - radius) < MERGE_STEP:
				merged = true
				break
		if not merged:
			radii.push_back(radius)
	radii.sort()
	return radii


func _draw() -> void:
	for radius in _radii:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, COLOR, WIDTH, true)
