extends SceneTree

# Грузит переданные скрипты так же, как игра: с зарегистрированными автозагрузками.
# Ошибки разбора Godot печатает сам, здесь только итог по каждому файлу.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in OS.get_cmdline_args():
		if not (path.begins_with("res://mods-unpacked/") or path.begins_with("res://zz_tools/ext/")):
			continue
		var script = load(path)
		var ok = script != null and script.can_instance()
		print("DCCHECK ", "ok   " if ok else "FAIL ", path)
	quit()
