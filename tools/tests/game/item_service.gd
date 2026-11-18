extends Node
var _tiers_data = []
var pools = {}
var item_groups = {}
func get_recycling_value(_wave,value,_index,_weapon):
 return int(max(1,value/4))
func get_item_box_recycling_value(_wave,value,_index,_weapon):
 return int(max(1,value/2))
func get_pool(_tier,type):
 return pools.get(type,[]).duplicate()
func update_pools(_pool,_backup,_index,_tier,_type):
 pass
func get_value(_wave,value,_index,_affected,_weapon,_id):
 return value
func get_stat_small_icon(_key):
 return null
