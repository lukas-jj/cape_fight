extends Control
signal proceed()

# Expose your boss images to the inspector so you can drag-and-drop them (and size/preview in the editor)
@export var boss_images: Array[Texture2D] = [
	preload("res://art/boss_overtime1.png"),
	preload("res://art/boss_overtime2.png"),
	preload("res://art/boss_overtime3.png"),
]

@onready var boss_gif := $BossGif
@onready var continue_button := $ContinueButton

func _ready():
	# only run at runtime
	if Engine.is_editor_hint():
		return

	randomize()
	if boss_images.size() == 0:
		push_warning("No boss images assigned!")
	else:
		var pick = boss_images[randi() % boss_images.size()]
		boss_gif.texture = pick

	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	emit_signal("proceed")
