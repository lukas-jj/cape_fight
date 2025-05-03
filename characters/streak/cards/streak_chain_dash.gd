extends Card

var base_damage := 4
const HITS := 2

func get_default_tooltip() -> String:
	return tooltip_text % [base_damage, HITS]

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_dmg := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_dmg = enemy_modifiers.get_modified_value(modified_dmg, Modifier.Type.DMG_TAKEN)
	return tooltip_text % [modified_dmg, HITS]

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	var dmg_amount := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	for i in range(HITS):
		var damage_effect := DamageEffect.new()
		damage_effect.amount = dmg_amount
		damage_effect.sound = sound
		damage_effect.execute(targets)
