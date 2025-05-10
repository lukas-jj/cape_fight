extends Card

const ENERGY_GAIN := 1
const CARDS_DRAWN := 1

func get_default_tooltip() -> String:
	return tooltip_text

func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	# Gain Energy (Mana)
	for target in targets:
		if target.has_variable("stats"):
			target.stats.mana += ENERGY_GAIN
	# Draw a Card
	var draw_effect := CardDrawEffect.new()
	draw_effect.cards_to_draw = CARDS_DRAWN
	draw_effect.sound = sound
	draw_effect.execute(targets)
