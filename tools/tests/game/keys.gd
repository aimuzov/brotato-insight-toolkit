extends Node
var empty_hash = 0
var hash_to_string = {}
var stat_armor_hash
var stat_dodge_hash
var stat_percent_damage_hash
var stat_max_hp_hash
var stat_hp_regeneration_hash
var stat_lifesteal_hash
var stat_melee_damage_hash
var stat_ranged_damage_hash
var stat_elemental_damage_hash
var stat_attack_speed_hash
var stat_crit_chance_hash
func _init():
 for name in ["stat_armor","stat_dodge","stat_percent_damage","stat_max_hp","stat_hp_regeneration","stat_lifesteal","stat_melee_damage","stat_ranged_damage","stat_elemental_damage","stat_attack_speed","stat_crit_chance"]:
  set(name + "_hash",generate_hash(name))
func generate_hash(name):
 var value = name.hash()
 hash_to_string[value] = name
 return value
