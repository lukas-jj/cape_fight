extends Card

const BLOCK_GAIN := 4
const DAMAGE := 6

func get_default_tooltip() -> String:
	return tooltip_text % [BLOCK_GAIN, DAMAGE]

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var dmg_mod := player_modifiers.get_modified_value(DAMAGE, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		dmg_mod = enemy_modifiers.get_modified_value(dmg_mod, Modifier.Type.DMG_TAKEN)
	return tooltip_text % [BLOCK_GAIN, dmg_mod]

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	# Gain Block on self
	var block_effect := BlockEffect.new()
	block_effect.amount = BLOCK_GAIN
	block_effect.sound = sound
	block_effect.execute(targets) # self targets (player group)

	# Deal Damage to targeted enemy
	var damage_effect := DamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(DAMAGE, Modifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets) # single enemy target
