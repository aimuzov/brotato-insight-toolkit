extends Node
const MUTANT_COLOR = Color(1,1,1)
var focused_control
func get_player_focused_control(_control,_index,_emulator=null):
 return focused_control
func get_stat(key,index):
 var player = RunData.players_data[index]
 var value = player.effects.get(key,0.0)*RunData.get_stat_gain(key,index)
 var temporary = TempStats.player_stats[index].get(key,0.0)*RunData.get_stat_gain(key,index)
 for link in player.effects.get(Keys.generate_hash("stat_links"),[]):
  if link[0] == key:
   var scaled = player.effects.get(link[2],0.0)*RunData.get_stat_gain(link[2],index)
   if not link[4]:
    scaled += TempStats.player_stats[index].get(link[2],0.0)*RunData.get_stat_gain(link[2],index)
   value += int(link[1]*scaled/link[3])*RunData.get_stat_gain(key,index)
 return value+temporary
func is_stat_key(key):
 return Keys.hash_to_string.get(key,"").begins_with("stat_")
func get_capped_stat(key,index):
 return get_stat(key,index)
