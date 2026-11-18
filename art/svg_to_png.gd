extends SceneTree

# Растеризует SVG в PNG средствами Godot 3.5: godot --no-window -s svg_to_png.gd <in_dir> <out_dir>


func _initialize() -> void:
	var args = OS.get_cmdline_args()
	var in_dir = args[args.size() - 2]
	var out_dir = args[args.size() - 1]
	var dir = Directory.new()
	dir.make_dir_recursive(out_dir)
	if dir.open(in_dir) != OK:
		printerr("can't open ", in_dir)
		quit(1)
		return
	dir.list_dir_begin(true)
	var name = dir.get_next()
	while name != "":
		if name.ends_with(".svg"):
			var image = Image.new()
			var error = image.load(in_dir.plus_file(name))
			if error == OK:
				image.save_png(out_dir.plus_file(name.get_basename() + ".png"))
				print("ok ", name)
			else:
				printerr("fail ", name, " ", error)
		name = dir.get_next()
	quit()
