extends Control
class_name EffectLine
var text = ""
var effect
var effect_icon = TextureRect.new()
var text_descr = RichTextLabel.new()
func _init():
 add_child(effect_icon)
 add_child(text_descr)
func _display_special_text(value,icon):
 text = value
 effect_icon.texture = icon
