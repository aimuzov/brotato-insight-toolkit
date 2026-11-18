extends Node

const Settings = preload("res://mods-unpacked/aimuzov-InsightToolkit/core/settings.gd")
const NOTICE_DURATION_MS = 1500
const NOTICE_FADE_MS = 250

var _wave_timer: Timer
var _normal_physics_rate = 60
var _applied_speed = 0
var _notice: Label
var _notice_until = 0


func _init(wave_timer: Timer) -> void:
	_wave_timer = wave_timer
	_normal_physics_rate = Engine.iterations_per_second
	pause_mode = PAUSE_MODE_PROCESS


func _ready() -> void:
	add_to_group("dc_wave_speed")
	_wave_timer.connect("timeout", self, "sync")
	_build_notice()
	sync()


func _process(_delta: float) -> void:
	sync()
	var remaining = _notice_until - OS.get_ticks_msec()
	_notice.visible = remaining > 0 and _is_in_wave()
	_notice.modulate.a = clamp(float(remaining) / NOTICE_FADE_MS, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_in_wave():
		return
	var button = -1
	if event is InputEventJoypadButton and event.pressed:
		button = event.button_index
	elif event is InputEventKey:
		if not event.pressed or event.echo or event.alt or event.shift or event.control or event.meta:
			return
		var key = event.physical_scancode if event.physical_scancode != 0 else event.scancode
		match key:
			KEY_MINUS:
				button = JOY_SONY_SQUARE
			KEY_EQUAL:
				button = JOY_SONY_TRIANGLE
			KEY_BACKSLASH:
				button = JOY_SONY_CIRCLE
	match button:
		JOY_SONY_SQUARE:
			_change_speed(-1)
		JOY_SONY_TRIANGLE:
			_change_speed(1)
		JOY_SONY_CIRCLE:
			ProgressData.settings.damage_display = not ProgressData.settings.damage_display
			ProgressData.save_settings()
			get_tree().call_group("dc_damage_display_options", "set_pressed_no_signal", ProgressData.settings.damage_display)
			_show_notice("Цифры урона: вкл." if ProgressData.settings.damage_display else "Цифры урона: выкл.")
		_:
			return
	get_tree().set_input_as_handled()


func _change_speed(direction: int) -> void:
	var current = Settings.wave_speed()
	var speed = int(clamp(current + direction, 1, 4))
	if speed != current:
		Settings.set_value("wave_speed", speed)
		sync()
		get_tree().call_group("dc_wave_speed_options", "set_value", speed)
	_show_notice("x%d" % speed)


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	_notice.show()
	_notice_until = OS.get_ticks_msec() + NOTICE_DURATION_MS


func _build_notice() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_notice = Label.new()
	_notice.add_font_override("font", load("res://resources/fonts/actual/base/font_40_outline.tres"))
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.align = Label.ALIGN_CENTER
	_notice.valign = Label.VALIGN_CENTER
	_notice.anchor_left = 0.5
	_notice.anchor_right = 0.5
	_notice.anchor_top = 0.16
	_notice.anchor_bottom = 0.16
	_notice.margin_left = -360
	_notice.margin_right = 360
	_notice.margin_top = 0
	_notice.margin_bottom = 56
	_notice.hide()
	layer.add_child(_notice)


func _is_in_wave() -> bool:
	return is_instance_valid(_wave_timer) and not _wave_timer.is_stopped() and _wave_timer.time_left > 0 and not get_tree().paused


func sync() -> void:
	var speed = Settings.wave_speed() if _is_in_wave() else 1
	if speed == _applied_speed:
		return
	_applied_speed = speed
	Engine.time_scale = float(speed)
	Engine.iterations_per_second = _normal_physics_rate * speed


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Engine.iterations_per_second = _normal_physics_rate
