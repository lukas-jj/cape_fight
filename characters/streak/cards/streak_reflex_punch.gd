extends Card

var base_damage := 6

func get_default_tooltip() -> String:
    return tooltip_text % base_damage

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    var dmg_effect = DamageEffect.new()
    var modified_dmg = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    dmg_effect.amount = modified_dmg
    dmg_effect.sound = sound
    dmg_effect.execute(targets)
    # If not first card this turn, gain 1 energy
    if character.played_cards_this_turn > 0:
        character.mana += 1
