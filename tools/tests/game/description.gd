extends Control
var effect_line = preload("res://line.tscn")
var effects = VBoxContainer.new()
func _init():
 add_child(effects)
 var original = Control.new()
 original.name = "OriginalEffect"
 effects.add_child(original)
func get_effects():
 return effects
func texts():
 var result = ""
 for child in effects.get_children():
  if child.name.begins_with("Dc"):
   result += child.text + "|"
 return result
