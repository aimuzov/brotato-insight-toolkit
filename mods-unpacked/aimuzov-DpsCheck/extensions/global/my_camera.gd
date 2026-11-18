extends "res://global/my_camera.gd"

# Соло: камера стоит на месте и показывает всю карту, как в BigMapSolo2.
# Включается в «Настройках» или горячей клавишей, клавиша меняет ту же настройку.
# В коопе не трогаем.

const DC_SETTINGS = "res://mods-unpacked/aimuzov-DpsCheck/core/settings.gd"
const DC_KEYS = {
	"key_z": KEY_Z, "key_x": KEY_X, "key_c": KEY_C, "key_f": KEY_F,
	"key_r": KEY_R, "key_v": KEY_V, "key_b": KEY_B, "key_space": KEY_SPACE,
}
const DC_JOY_BUTTONS = {
	"joy_r3": JOY_R3, "joy_l3": JOY_L3, "joy_y": JOY_XBOX_Y, "joy_x": JOY_XBOX_X, "joy_select": JOY_SELECT,
}

var _dc_settings


# Базовый _ready Godot 3 вызывает сам, явный ._ready() запустил бы его дважды
func _ready() -> void:
	_dc_settings = load(DC_SETTINGS)


func _input(event: InputEvent) -> void:
	if RunData.is_coop_run or not _dc_is_toggle(event):
		return
	_dc_settings.set_value("wide_camera", not _dc_settings.enabled("wide_camera"))
	get_tree().set_input_as_handled()


func _dc_is_toggle(event: InputEvent) -> bool:
	var toggle = str(_dc_settings.value("wide_camera_toggle"))
	if toggle == "mouse_middle":
		return event is InputEventMouseButton and event.button_index == BUTTON_MIDDLE and event.pressed
	if DC_KEYS.has(toggle):
		return event is InputEventKey and event.pressed and not event.is_echo() and event.scancode == DC_KEYS[toggle]
	if DC_JOY_BUTTONS.has(toggle):
		return event is InputEventJoypadButton and event.pressed and event.button_index == DC_JOY_BUTTONS[toggle]
	return false


# wide_camera_zoom 1.0 — максимальное отдаление, которое игра сама допускает (_max_zoom)
func _adjust_zoom(alive_targets: Array, delta: float) -> void:
	if not RunData.is_coop_run and _dc_settings != null and _dc_settings.enabled("wide_camera"):
		var amount = clamp(float(_dc_settings.value("wide_camera_zoom")), 0.0, 1.0)
		var value = 1.0 + amount * (_max_zoom - 1.0)
		zoom = Vector2(value, value)
		return
	._adjust_zoom(alive_targets, delta)
