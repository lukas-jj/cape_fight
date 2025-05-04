extends Control
signal proceed()

# Expose your boss images to the inspector so you can drag-and-drop them (and size/preview in the editor)
@export var boss_images: Array[Texture2D] = [
	preload("res://art/boss_overtime1.png"),
	preload("res://art/boss_overtime2.png"),
	preload("res://art/boss_overtime3.png"),
]
const RunClass = preload("res://scenes/run/run.gd")

@onready var boss_gif := $BossGif
@onready var continue_button := $ContinueButton

func _ready():
	# only run at runtime
	if Engine.is_editor_hint():
		return

	# try loading a custom intro image based on character_name
	var run_node = self
	while run_node and not run_node is RunClass:
		run_node = run_node.get_parent()
	var char_name = ""
	if run_node and run_node.character:
		char_name = run_node.character.character_name.to_lower().replace(" ", "_")
	var path = "res://art/%s_intro.png" % char_name
	if char_name != "" and FileAccess.file_exists(path):
		boss_gif.texture = load(path)
	else:
		randomize()
		if boss_images.size() == 0:
			push_warning("No boss images assigned!")
		else:
			var pick = boss_images[randi() % boss_images.size()]
			boss_gif.texture = pick

	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	emit_signal("proceed")
