extends Card

var block_amount := 4
var energy_refund := 1

func get_default_tooltip() -> String:
	return tooltip_text % [block_amount, energy_refund]

func get_updated_tooltip(player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	var modified_block := player_modifiers.get_modified_value(block_amount, Modifier.Type.BLOCK_GAINED)
	return tooltip_text % [modified_block, energy_refund]

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	# Apply block
	var block_effect := BlockEffect.new()
	block_effect.amount = modifiers.get_modified_value(block_amount, Modifier.Type.BLOCK_GAINED)
	block_effect.sound = sound
	block_effect.execute(targets)
	
	# Refund energy
	var character := targets[0].get_tree().get_first_node_in_group("char_stats") as CharacterStats
	if character:
		character.mana += energy_refund
