extends Card

var base_damage := 8

func get_default_tooltip() -> String:
	return tooltip_text % base_damage

func get_updated_tooltip(player_modifiers: ModifierHandler, enemy_modifiers: ModifierHandler) -> String:
	var modified_dmg := player_modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	if enemy_modifiers:
		modified_dmg = enemy_modifiers.get_modified_value(modified_dmg, Modifier.Type.DMG_TAKEN)
	return tooltip_text % modified_dmg

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
	# Deal damage that ignores current block by adding it to the damage amount
	for target in targets:
		if not target:
			continue
		var dmg_amount := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
		if target.stats:
			dmg_amount += target.stats.block
		var damage_effect := DamageEffect.new()
		damage_effect.amount = dmg_amount
		damage_effect.sound = sound
		damage_effect.execute([target])
