# EditorScript to ensure every Card resource has a title
# Run from Godot editor: Project -> Tools -> Select this script and click Run
extends EditorScript

const CARD_SCRIPT : Script = preload("res://custom_resources/card.gd")

func _run() -> void:
	var updated := 0
	var checked := 0

	# Search all .tres files under characters/*/cards/
	var dir := DirAccess.open("res://characters")
	if dir == null:
		push_error("[AddTitles] characters directory not found")
		return

	_dir_walk(dir, "res://characters", checked, updated)

	print("[AddTitles] Checked %d card resources, added titles to %d." % [checked, updated])

func _dir_walk(d: DirAccess, path: String, checked: int, updated: int) -> void:
	for file in d.get_files():
		if file.ends_with(".tres") and file.contains("cards"):
			var full_path := path + "/" + file
			if ResourceLoader.exists(full_path):
				var res := load(full_path)
				if res is Card:
					checked += 1
					if str(res.title).strip_edges() == "":
						res.title = _derive_title_from_id(res.id)
						var err := ResourceSaver.save(res, full_path)
						if err == OK:
							updated += 1
						else:
							push_warning("[AddTitles] Failed to save %s (err=%s)" % [full_path, err])
	for sub in d.get_directories():
		var sub_path := path + "/" + sub
		var sub_dir := DirAccess.open(sub_path)
		_dir_walk(sub_dir, sub_path, checked, updated)

func _derive_title_from_id(id_str: String) -> String:
	var parts := id_str.split("_", false)
	if parts.size() > 1:
		parts = parts.slice(1, parts.size())
	return " ".join(parts).capitalize().replace("_", " ")
