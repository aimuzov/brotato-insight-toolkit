extends Resource
class_name Effect
enum StorageMethod {SUM,KEY_VALUE,REPLACE,APPEND_KEY,APPEND_KEY_VALUE}
enum Sign {POSITIVE,NEGATIVE,NEUTRAL,FROM_VALUE}
var key = "stat_max_hp"
var key_hash = 0
var value = 0
var custom_key = ""
var custom_key_hash = 0
var custom_args = []
var storage_method = StorageMethod.SUM
var effect_sign = Sign.FROM_VALUE
var added_by_mutation = false
var base_value = 0
var applied_override = null
func get_id():
 return "effect"
func get_applied_value(_index):
	return applied_override if applied_override != null else value
func get_sign(_sign, amount):
 return Sign.POSITIVE if amount >= 0 else Sign.NEGATIVE
func serialize():
 return {"key":key,"value":value}
var text_key = ""
func get_text(_index):
 return "%s %+d" % [key,value]
