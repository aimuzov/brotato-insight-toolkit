extends Node
var players_data = []
var current_wave = 6
var current_zone = 0
var current_difficulty = 0
var nb_of_waves = 20
var is_endless_run = false
var is_coop_run = false
func get_player_count():
 return players_data.size()
func get_player_character(index):
 return players_data[index].current_character
func get_player_weapons(index):
 return players_data[index].weapons.duplicate()
func get_player_items(index):
 return players_data[index].items.duplicate()
func get_player_effects(index):
 return players_data[index].effects
func get_player_gold(index):
 return players_data[index].gold
func get_player_currency(index):
 return get_player_gold(index)
func get_stat_gain(key,index):
 var name = Keys.hash_to_string.get(key,"")
 return 1.0 + players_data[index].effects.get(Keys.generate_hash("gain_"+name),0.0)/100.0
func get_armor_coef(armor):
 var coefficient = 1.0/(1.0+abs(armor)/15.0)
 return 2.0-coefficient if armor<0 else coefficient
