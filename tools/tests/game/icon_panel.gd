extends Panel

func _init():
 var icon = TextureRect.new()
 icon.name = "Icon"
 add_child(icon)
 var count = Label.new()
 count.name = "Count"
 add_child(count)

func set_count(amount):
 get_node("Count").text = "x" + str(amount)
 get_node("Count").visible = amount > 1

func _update_stylebox(_cursed,_tier):
 pass
