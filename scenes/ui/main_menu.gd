extends Control

const PvpData := preload("res://pvp_data.gd")

const CHAR_SELECTOR_SCENE := preload("res://scenes/ui/character_selector.tscn")
const RUN_SCENE           := preload("res://scenes/run/run.tscn")

@export var run_startup: RunStartup

@onready var continue_button: Button = %Continue
@onready var vs_ai_button    : Button = %VsAI

# ---------------------------------------------------------------
func _ready() -> void:
	get_tree().paused = false
	continue_button.disabled = (SaveGame.load_data() == null)
	vs_ai_button.pressed.connect(_on_vs_ai_pressed)

# ---------------------------------------------------------------
func _on_continue_pressed() -> void:
	run_startup.type = RunStartup.Type.CONTINUED_RUN
	get_tree().change_scene_to_packed(RUN_SCENE)

# ---------------------------------------------------------------
func _on_new_run_pressed() -> void:
	PvpData.vs_ai_enabled = false
	PvpData.player_stats  = null
	PvpData.ai_stats      = null
	print("[MainMenu] New-Run  vs_ai:", PvpData.vs_ai_enabled,
		  " player_stats:", PvpData.player_stats,
		  " ai_stats:", PvpData.ai_stats)
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)

# ---------------------------------------------------------------
func _on_exit_pressed() -> void:
	get_tree().quit()

# ---------------------------------------------------------------
func _on_vs_ai_pressed() -> void:
	PvpData.vs_ai_enabled = true
	PvpData.player_stats  = null      # selector will set
	PvpData.ai_stats      = null      # selector will set
	print("[MainMenu] VS-AI pressed →",
		  " vs_ai:", PvpData.vs_ai_enabled,
		  " player_stats:", PvpData.player_stats,
		  " ai_stats:", PvpData.ai_stats)
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)
