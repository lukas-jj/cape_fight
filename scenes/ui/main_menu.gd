extends Control

const CHAR_SELECTOR_SCENE := preload("res://scenes/ui/character_selector.tscn")
const RUN_SCENE = preload("res://scenes/run/run.tscn")
const VS_AI_SCENE := preload("res://scenes/pvp/vs_ai.tscn")

@export var run_startup: RunStartup

@onready var continue_button: Button = %Continue
@onready var vs_ai_button: Button = %VsAI


func _ready() -> void:
	get_tree().paused = false
	continue_button.disabled = SaveGame.load_data() == null
	vs_ai_button.pressed.connect(_on_vs_ai_pressed)


func _on_continue_pressed() -> void:
	run_startup.type = RunStartup.Type.CONTINUED_RUN
	get_tree().change_scene_to_packed(RUN_SCENE)


func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_vs_ai_pressed() -> void:
	get_tree().change_scene_to_packed(VS_AI_SCENE)
