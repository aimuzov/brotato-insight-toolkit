extends Reference

const HUD_FONT = "res://resources/fonts/actual/base/font_26_outline.tres"

const BAD = Color(0.721569, 0.0, 0.0)
const BEST = Color("ffd75e")
const MUTED = Color(1, 1, 1, 0.55)


static func font(size: int):
	var base = load(HUD_FONT)
	if not base is DynamicFont:
		return base
	var result = base.duplicate()
	result.size = size
	return result


static func label(text: String, size: int, color: Color = Color.white) -> Label:
	var result = Label.new()
	result.text = text
	result.add_font_override("font", font(size))
	result.modulate = color
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func icon(texture: Texture, size: int) -> TextureRect:
	var result = TextureRect.new()
	result.texture = texture
	result.expand = true
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.rect_min_size = Vector2(size, size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func stat_icon(stat_hash: int):
	return ItemService.get_stat_icon(stat_hash)


static func num(value: float) -> String:
	return Text.get_formatted_number(int(round(value)))
