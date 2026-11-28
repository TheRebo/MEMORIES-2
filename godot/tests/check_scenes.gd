# Loads and instantiates every .tscn in the project, so a broken ext_resource path, a missing
# script or a bad node property fails CI. Exit 1 if any scene cannot be loaded.
extends SceneTree


func _initialize() -> void:
	var broken := 0
	var files := _find("res://")
	for path in files:
		var packed := load(path) as PackedScene
		if packed == null or not packed.can_instantiate():
			broken += 1
			printerr("BROKEN SCENE ", path)
			continue
		var node := packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		if node == null:
			broken += 1
			printerr("CANNOT INSTANTIATE ", path)
		else:
			node.free()
	print("scenes checked: %d, broken: %d" % [files.size(), broken])
	quit(1 if broken > 0 else 0)


func _find(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tscn":
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			out.append_array(_find(dir.path_join(sub)))
	return out
