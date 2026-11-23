extends Button
var item
var player_index = 0
var _recently_mutated = Control.new()
func _init():
 add_child(_recently_mutated)
func set_element(data: Resource):
 item = data
 _recently_mutated.show()
