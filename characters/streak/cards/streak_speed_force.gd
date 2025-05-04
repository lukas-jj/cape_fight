extends Card

var draw_on_play := 1
var draw_next_turn := 2

func get_default_tooltip() -> String:
	return tooltip_text % [draw_on_play, draw_next_turn]

func get_updated_tooltip(_player_modifiers: ModifierHandler, _enemy_modifiers: ModifierHandler) -> String:
	return tooltip_text % [draw_on_play, draw_next_turn]

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
	# Draw cards immediately
	var immediate_draw := CardDrawEffect.new()
	immediate_draw.cards_to_draw = draw_on_play
	immediate_draw.sound = sound
	immediate_draw.execute(targets)
	
	# Set up draw for next turn (this would need proper implementation in the game)
	# Could be implemented with a status effect that draws cards at the start of turn
	var speed_force_status = Status.new()
	speed_force_status.id = "speed_force"
	speed_force_status.type = Status.Type.START_OF_TURN
	speed_force_status.stack_type = Status.StackType.DURATION
	speed_force_status.can_expire = true
	speed_force_status.duration = 1
	speed_force_status.stacks = draw_next_turn
	
	var status_effect := StatusEffect.new()
	status_effect.status = speed_force_status
	status_effect.execute(targets)
