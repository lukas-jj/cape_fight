extends CardState

var mouse_over_card := false


func enter() -> void:
	if not card_ui.is_node_ready():
		await card_ui.ready

	if card_ui.tween and card_ui.tween.is_running():
		card_ui.tween.kill()

	card_ui.card_visuals.panel.set("theme_override_styles/panel", card_ui.BASE_STYLEBOX)
	if not card_ui.get_parent() is CardSlot:
		card_ui.reparent_requested.emit(card_ui)
	card_ui.pivot_offset = Vector2.ZERO
	Events.tooltip_hide_requested.emit()


func on_gui_input(event: InputEvent) -> void:
	# If the card is currently inside a CardSlot, a left-click will **un-select** it and send it back to the Hand
	if card_ui.get_parent() is CardSlot and event.is_action_pressed("left_mouse"):
		var slot := card_ui.get_parent() as CardSlot
		# Clear slot reference & notify
		slot.card_ui = null
		slot.emit_signal("card_changed", null)
		# Move card back to original hand container stored in `card_ui.parent`
		if card_ui.parent and is_instance_valid(card_ui.parent):
			card_ui.reparent(card_ui.parent)
			card_ui.scale = Vector2.ONE
			card_ui.disabled = false
			# Place it roughly back to its original index so ordering feels consistent
			var new_index := clampi(card_ui.original_index, 0, card_ui.parent.get_child_count())
			card_ui.parent.move_child.call_deferred(card_ui, new_index)
		return

	if not card_ui.playable or card_ui.disabled:
		return

	if mouse_over_card and event.is_action_pressed("left_mouse"):
		card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
		transition_requested.emit(self, CardState.State.CLICKED)


func on_mouse_entered() -> void:
	mouse_over_card = true
	
	if not card_ui.playable or card_ui.disabled:
		return

	card_ui.card_visuals.panel.set("theme_override_styles/panel", card_ui.HOVER_STYLEBOX)
	card_ui.request_tooltip()


func on_mouse_exited() -> void:
	mouse_over_card = false
	
	if not card_ui.playable or card_ui.disabled:
		return

	card_ui.card_visuals.panel.set("theme_override_styles/panel", card_ui.BASE_STYLEBOX)
	Events.tooltip_hide_requested.emit()
