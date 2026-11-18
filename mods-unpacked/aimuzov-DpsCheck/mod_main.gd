extends Node

const MOD_ID = "aimuzov-DpsCheck"
const LOG_NAME = "aimuzov-DpsCheck:Main"

var _dir = ""


func _init() -> void:
	_dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID)
	load(_dir.plus_file("core/translations.gd")).apply()

	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/main.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/items/global/inventory_element.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/meca_parts_ui.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/item_description.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/item_popup.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/stat_container.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/secondary_stat_container.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/stats_container.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/coop_shop_player_container.gd"))
	# Камеру ставим всегда: её переключают в «Настройках» прямо во время игры
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/global/my_camera.gd"))

	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/shop.gd"))
	ModLoaderMod.install_script_extension(_dir.plus_file("extensions/ui/menus/shop/coop_shop.gd"))

	ModLoaderLog.info("Installed", LOG_NAME)


func _ready() -> void:
	add_child(load(_dir.plus_file("ui/compact_numbers.gd")).new())
	# Ждём, пока все автозагрузки игры, включая ItemService, будут готовы
	call_deferred("_apply_data_tweaks")
	# Меню настроек появляется и в главном экране, и в паузе: ловим каждое появление
	var _e = get_tree().connect("node_added", self, "_on_node_added")


func _exit_tree() -> void:
	load(_dir.plus_file("core/translations.gd")).restore_original()


func _apply_data_tweaks() -> void:
	load(_dir.plus_file("core/stat_names.gd")).apply()


func _on_node_added(node: Node) -> void:
	if not _is_options_menu(node):
		return
	# onready-поля меню ещё пустые: дописываем раздел, когда оно будет готово
	if not node.is_connected("ready", self, "_on_menu_ready"):
		var _e = node.connect("ready", self, "_on_menu_ready", [node], CONNECT_ONESHOT)


# Меню узнаём по скрипту в цепочке наследования: имя узла в сценах разное,
# а ModOptions подменяет сцену своим наследником того же скрипта
func _is_options_menu(node: Node) -> bool:
	var script = node.get_script()
	while script != null:
		if script.resource_path.get_basename() == "res://ui/menus/pages/menu_options":
			return true
		script = script.get_base_script()
	return false


func _on_menu_ready(menu: Node) -> void:
	load(_dir.plus_file("ui/options_section.gd")).inject(menu)
