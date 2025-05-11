extends Control

# Ensure compiler sees PvpData even if not yet globally registered
const PvpData := preload("res://pvp_data.gd")

const CHAR_SELECTOR_SCENE := preload("res://scenes/ui/character_selector.tscn")
const RUN_SCENE = preload("res://scenes/run/run.tscn")

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
	PvpData.vs_ai_enabled = true
	PvpData.ai_stats = preload("res://characters/warrior/warrior.tres")
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)
