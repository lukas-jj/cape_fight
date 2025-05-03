extends Card

const BLOCK_AMOUNT := 2

func get_default_tooltip() -> String:
	return tooltip_text % BLOCK_AMOUNT

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	# Gain block
	var block_effect = BlockEffect.new()
	block_effect.amount = BLOCK_AMOUNT
	block_effect.sound = sound
	block_effect.execute(targets)
	# TODO: Reduce cost of next card this turn by 1
