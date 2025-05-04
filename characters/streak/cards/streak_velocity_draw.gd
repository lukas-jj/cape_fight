extends Card

var cards_to_draw := 2

func get_default_tooltip() -> String:
	return tooltip_text % [cards_to_draw]

func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text % [cards_to_draw]

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	var card_draw_effect := CardDrawEffect.new()
	card_draw_effect.cards_to_draw = cards_to_draw
	card_draw_effect.sound = sound
	card_draw_effect.execute(targets)
