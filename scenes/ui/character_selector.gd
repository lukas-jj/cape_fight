extends Control
const PvpData := preload("res://pvp_data.gd")

# ─────────── playable heroes ────────────
const WARRIOR_STATS := preload("res://characters/warrior/warrior.tres")
const STREAK_STATS  := preload("res://characters/streak/streak.tres")

var CHARACTER_POOL: Array[CharacterStats] = [
	WARRIOR_STATS, STREAK_STATS   # only two heroes
]

# ─────────── scene paths ────────────────
const PVP_SCENE := preload("res://scenes/pvp/pvp_battle.tscn")
const RUN_SCENE := preload("res://scenes/run/run.tscn")

@export var run_startup: RunStartup

# ─────────── UI nodes (mandatory) ───────
@onready var title             : Label       = %Title
@onready var description       : Label       = %Description
@onready var character_portrait: TextureRect = %CharacterPortrait
@onready var warrior_btn       : Button      = %WarriorButton
@onready var streak_btn        : Button      = %StreakButton

# ─────────── optional buttons to disable ─
var other_buttons: Array[Button] = []

# current choice -------------------------------------------------
var current_character: CharacterStats : set = set_current_character

# ----------------------------------------------------------------
func _ready() -> void:
	_disable_unused_buttons()
	set_current_character(WARRIOR_STATS)

# disable Wizard / Assassin / Hunter / Nurse if they exist -------
func _disable_unused_buttons() -> void:
	var to_check := ["WizardButton", "AssassinButton", "HunterButton", "NurseButton"]
	for name in to_check:
		var btn := get_node_or_null("%" + name)
		if btn != null:
			btn.disabled = true
			btn.text += " (Coming Soon)"
			other_buttons.append(btn)

# ---------------- button handlers -------------------------------
func _on_warrior_button_pressed() -> void:
	set_current_character(WARRIOR_STATS)

func _on_streak_button_pressed() -> void:
	set_current_character(STREAK_STATS)

# set current hero ------------------------------------------------
func set_current_character(ch: CharacterStats) -> void:
	current_character          = ch
	title.text                 = ch.character_name
	description.text           = ch.description
	character_portrait.texture = ch.portrait

# ---------------- START button ----------------------------------
func _on_start_button_pressed() -> void:
	# store player hero
	PvpData.player_stats = current_character

	# when VS-AI is on, AI gets the other hero
	if PvpData.vs_ai_enabled:
		var ai_char: CharacterStats
		if current_character == WARRIOR_STATS:
			ai_char = STREAK_STATS
		else:
			ai_char = WARRIOR_STATS
		PvpData.ai_stats = ai_char
	else:
		PvpData.ai_stats = null

	# launch correct scene
	run_startup.type = RunStartup.Type.NEW_RUN
	run_startup.picked_character = current_character

	var target: PackedScene
	if PvpData.vs_ai_enabled:
		target = PVP_SCENE
	else:
		target = RUN_SCENE

	get_tree().change_scene_to_packed(target)
