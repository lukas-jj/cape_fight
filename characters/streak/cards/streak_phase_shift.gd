extends Card

const INTANGIBLE_STATUS = preload("res://statuses/intangible.tres")
var duration := 1

func get_default_tooltip() -> String:
	return tooltip_text % [duration]

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	# Intangible isn't modified by DMG stats, so same tooltip
	return tooltip_text % [duration]

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var status_effect := StatusEffect.new()
	var status = INTANGIBLE_STATUS.duplicate()
	status.duration = duration
	status_effect.status = status
	status_effect.execute(targets)
