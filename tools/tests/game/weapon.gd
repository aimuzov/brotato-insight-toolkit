extends ItemParentData
class_name WeaponData
enum Type {MELEE,RANGED}
var stats
var type = Type.RANGED
var sets = []
var upgrades_into
var weapon_id = "weapon_test"
var dmg_dealt_last_wave = 0
