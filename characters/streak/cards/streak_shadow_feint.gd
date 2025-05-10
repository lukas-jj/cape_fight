extends Card

const CARDS_DRAWN := 1
const BONUS_DAMAGE := 3

func get_default_tooltip() -> String:
	return tooltip_text % [CARDS_DRAWN, BONUS_DAMAGE]

func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text % [CARDS_DRAWN, BONUS_DAMAGE]

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	# Draw a Card
	var draw_effect := CardDrawEffect.new()
	draw_effect.cards_to_draw = CARDS_DRAWN
	draw_effect.sound = sound
	draw_effect.execute(targets)

	# Add one-shot +3 damage for next attack via status‐like modifier
	var player: Player = targets[0]
	var dmg_mod: Modifier = player.modifier_handler.get_modifier(Modifier.Type.DMG_DEALT)
	var temp_val := ModifierValue.create_new_modifier("shadow_feint", ModifierValue.Type.FLAT)
	temp_val.flat_value = BONUS_DAMAGE
	dmg_mod.add_new_value(temp_val)

	# Remove after one card played
	Events.card_played.connect(func(_card): dmg_mod.remove_value("shadow_feint"), CONNECT_ONE_SHOT)
