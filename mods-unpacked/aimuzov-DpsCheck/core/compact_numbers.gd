extends Reference

const Display = preload("damage_display.gd")

var _numbers = RegEx.new()
var _protected = RegEx.new()
var _cache = {}


func _init() -> void:
	_numbers.compile("(?<![\\p{L}\\p{N}_.])(?:[0-9]{1,3}(?:[, \\x{00a0}\\x{202f}][0-9]{3})+|[0-9]+)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?(?![\\p{N}_.kKкК])")
	var protected_parts = [
		"\\[img[^\\]]*\\].*?\\[/img\\]",
		"\\[url[^\\]]*\\].*?\\[/url\\]",
		"\\[[^\\]\\r\\n]*\\]",
		"(?:https?|res|user)://\\S+",
		"#[0-9a-f]{3,8}\\b",
		"(?:©|copyright)\\s*(?:19|20)[0-9]{2}",
		"(?<![0-9])[0-9]{3,5}\\s*[x×]\\s*[0-9]{3,5}(?![0-9])",
		"(?<![0-9])(?:(?:19|20)[0-9]{2}[-/.][0-9]{1,2}[-/.][0-9]{1,2}|[0-9]{1,2}[-/.][0-9]{1,2}[-/.](?:19|20)[0-9]{2})(?![0-9])",
		"(?<![\\w.])v?[0-9]+(?:\\.[0-9]+){2,}(?![\\w.])",
		"(?:seed|[сС][иИ][дД]|[зЗ][еЕ][рР][нН][оО])\\s*[:=]?\\s*[-+]?[0-9]+",
	]
	_protected.compile("(?is)" + PoolStringArray(protected_parts).join("|"))


func format(source: String) -> String:
	if _cache.has(source):
		return _cache[source]
	var result = ""
	var cursor = 0
	for part in _protected.search_all(source):
		result += _plain(source.substr(cursor, part.get_start() - cursor))
		result += part.get_string()
		cursor = part.get_end()
	result += _plain(source.substr(cursor))
	if _cache.size() >= 512:
		_cache.clear()
	_cache[source] = result
	return result


func _plain(source: String) -> String:
	var result = ""
	var cursor = 0
	for part in _numbers.search_all(source):
		var text = part.get_string()
		var raw = text.replace(",", "").replace(" ", "").replace("\u00a0", "").replace("\u202f", "")
		var value = float(raw)
		result += source.substr(cursor, part.get_start() - cursor)
		result += Display.number(value) if value >= 1000.0 else text
		cursor = part.get_end()
	return result + source.substr(cursor)
