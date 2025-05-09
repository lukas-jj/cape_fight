class_name Campfire
extends Control

@export var char_stats: CharacterStats
@export var campfire_background: Texture2D = preload("res://art/background art game.png")

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var rest_button: Button = %RestButton
@onready var bg_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    bg_sprite.texture = campfire_background

func _on_rest_button_pressed() -> void:
    rest_button.disabled = true
    char_stats.heal(ceili(char_stats.max_health * 0.3))
    animation_player.play("fade_out")


# This is called from the AnimationPlayer
# at the end of 'fade-out'.
func _on_fade_out_finished() -> void:
    Events.campfire_exited.emit()
