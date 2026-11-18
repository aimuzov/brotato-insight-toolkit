extends Camera2D

# Заглушка res://global/my_camera.gd для проверки расширения камеры

var zoom_in_speed_factor: = 0.6
var zoom_out_speed_factor: = 0.99
var _max_zoom: float = 1.0


func _adjust_zoom(_alive_targets: Array, _delta: float) -> void:
	pass
