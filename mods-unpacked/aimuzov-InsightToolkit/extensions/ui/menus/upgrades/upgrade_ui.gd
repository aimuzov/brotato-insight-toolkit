extends "res://ui/menus/upgrades/upgrade_ui.gd"

const CONTENT_GAP = 8


func _ready() -> void:
	# В горизонтальном ряду FILL растягивает короткую карточку до высоты соседней.
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var margin = get_node("MarginContainer")
	margin.add_constant_override("margin_top", CONTENT_GAP)
	margin.add_constant_override("margin_bottom", CONTENT_GAP)
	var description = get_node("%UpgradeDescription")
	# Ширину ряда раньше задавал заголовок с крупной иконкой.
	if description.get_parent() == margin:
		# В кооперативе варианты стоят в колонке, ширину задаёт область игрока.
		size_flags_horizontal = Control.SIZE_FILL
	else:
		rect_min_size.x = get_combined_minimum_size().x
	description.get_node("HBoxContainer").hide()
	description.add_constant_override("separation", CONTENT_GAP)
	var spacer = get_node_or_null("MarginContainer/VBoxContainer/EmptySpace")
	if spacer != null:
		spacer.hide()
		spacer.get_parent().add_constant_override("separation", CONTENT_GAP)

	var scroll = description.get_node("ScrollContainer")
	var content = scroll.get_node("VBoxContainer")
	# Штатная высота прокрутки нужна лишь тогда, когда описание длинное.
	var max_height = scroll.rect_min_size.y
	content.connect("minimum_size_changed", self, "_dc_fit_upgrade", [scroll, content, max_height])
	_dc_fit_upgrade(scroll, content, max_height)


func _dc_fit_upgrade(scroll: ScrollContainer, content: VBoxContainer, max_height: float) -> void:
	var padding = scroll.get_stylebox("bg").get_minimum_size().y
	scroll.rect_min_size.y = min(max_height, content.get_combined_minimum_size().y + padding)
