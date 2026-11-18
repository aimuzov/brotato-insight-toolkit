extends Translation

var _catalogue = {}
var _english: Translation
var _original: Translation


func _init(catalogue: Dictionary, english: Translation, original: Translation) -> void:
	_catalogue = catalogue
	_english = english
	_original = original
	set_locale(original.get_locale())


func _get_message(key: String) -> String:
	if _catalogue.by_key.has(key):
		return _catalogue.by_key[key]
	var source = _english.get_message(key).replace("\r\n", "\n")
	if source != "" and _catalogue.by_source.has(source):
		return _catalogue.by_source[source]
	return _original.get_message(key)
