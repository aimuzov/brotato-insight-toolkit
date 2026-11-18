extends Node

# Заглушка res://main.gd для проверки расширения: только то, к чему оно обращается

var _wave_timer: Timer
var _wave_timer_label: Label
var _entity_spawner
var _wave_manager
var _players = []
var _upgrades_ui
var _coop_upgrades_ui


func get_gold_value(_entity_type: int, _args, _base_value: float, _unit = null) -> float:
	return 0.0
