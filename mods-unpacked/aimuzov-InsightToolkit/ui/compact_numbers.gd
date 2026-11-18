extends Node

const CompactNumbers = preload("res://mods-unpacked/aimuzov-InsightToolkit/core/compact_numbers.gd")
const Settings = preload("res://mods-unpacked/aimuzov-InsightToolkit/core/settings.gd")
var _formatter = CompactNumbers.new()
var _labels = {}
var _last = {}
var _original = {}
var _pending = {}
var _queued = false
var _scan_at = 0


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	add_to_group("dc_short_numbers")
	get_tree().connect("node_added", self, "_track")
	_track_tree(get_tree().root)


func _track_tree(node: Node) -> void:
	_track(node)
	for child in node.get_children():
		_track_tree(child)


func _track(node: Node) -> void:
	if not _eligible(node):
		return
	var id = node.get_instance_id()
	_labels[id] = weakref(node)
	if not node.is_connected("minimum_size_changed", self, "_queue"):
		node.connect("minimum_size_changed", self, "_queue", [id])
	if not node.is_connected("visibility_changed", self, "_queue"):
		node.connect("visibility_changed", self, "_queue", [id])
	_queue(id)


func _queue(id: int) -> void:
	_pending[id] = true
	if not _queued:
		_queued = true
		call_deferred("_flush")


func _flush() -> void:
	_queued = false
	var pending = _pending.keys()
	_pending.clear()
	for id in pending:
		if _labels.has(id):
			apply_node(_labels[id].get_ref())


func _process(_delta: float) -> void:
	var now = OS.get_ticks_msec()
	if now < _scan_at:
		return
	_scan_at = now + 100
	for id in _labels.keys():
		var node = _labels[id].get_ref()
		if not is_instance_valid(node):
			_labels.erase(id)
			_last.erase(id)
			_original.erase(id)
		elif node.is_visible_in_tree():
			apply_node(node)


func apply_node(node) -> void:
	if not is_instance_valid(node) or not _eligible(node) or node.is_queued_for_deletion():
		return
	var rich = node is RichTextLabel and node.bbcode_enabled
	var source = node.bbcode_text if rich else node.text
	var id = node.get_instance_id()
	if not Settings.enabled("short_numbers"):
		if _last.has(id) and source == _last[id] and _original.has(id):
			_set_text(node, _original[id], rich)
		_last.erase(id)
		_original.erase(id)
		return
	if _last.get(id) == source:
		return
	_original[id] = source
	var formatted = _formatter.format(source)
	_last[id] = formatted
	if source == formatted:
		return
	_set_text(node, formatted, rich)


func _dc_refresh_short_numbers() -> void:
	for id in _labels.keys():
		apply_node(_labels[id].get_ref())


static func _set_text(node, text: String, rich: bool) -> void:
	if rich:
		if node.bbcode_text != text:
			node.bbcode_text = text
	elif node.text != text:
		node.text = text


static func _eligible(node: Node) -> bool:
	if node.has_meta("dc_numbers_formatted"):
		return false
	return node is Label or node is RichTextLabel or node is Button
