extends Card

var base_block := 10

func get_default_tooltip() -> String:
	return tooltip_text % base_block

func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text % base_block

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	# Apply block
	var block_effect := BlockEffect.new()
	block_effect.amount = base_block
	block_effect.sound = sound
	block_effect.execute(targets)

	# Apply Braced Defense status for later triggering
	if targets.size() > 0 and targets[0].has_node("StatusHandler"):
		var status_instance = preload("res://statuses/braced_defense.tres").duplicate()
		targets[0].get_node("StatusHandler").add_status(status_instance)
