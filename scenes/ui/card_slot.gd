class_name CardSlot
extends Panel

# Slot that accepts a single CardUI during selection phase.

# Emitted whenever the slot's card changes (added, swapped, or cleared)
signal card_changed(card_ui: CardUI)

var card_ui: CardUI = null

func _ready() -> void:
	add_to_group("card_slots")
	# Designer will control visual style and size in the editor; no runtime overrides here

func is_empty() -> bool:
	return card_ui == null or not is_instance_valid(card_ui)

# Returns a human-readable name for debugging
func _debug_card_name(cardui: CardUI) -> String:
	if cardui == null or cardui.card == null:
		return "<null>"
	var c := cardui.card
	if c.title != "":
		return c.title
	if c.id != "":
		return c.id
	if c.resource_name != "":
		return c.resource_name
	return c.resource_path.get_file()

func accept_card(card: CardUI) -> void:
	if card == null:
		return
	var incoming_card_name := _debug_card_name(card)
	print("[CardSlot] slot %d ACCEPT() PARAM → %s (CardUI id: %d)" % [get_index(), incoming_card_name, card.get_instance_id()])
	
	var incoming_prev_parent := card.get_parent()
	var outgoing: CardUI = card_ui  # May be null if slot was empty

	# === Place the incoming card into THIS slot ===
	card_ui = card
	card.reparent(self)
	var slot_size := get_size()
	var scale_factor: float = min(slot_size.x / card.size.x, slot_size.y / card.size.y)
	card.scale = Vector2.ONE * scale_factor
	var card_drawn_size: Vector2 = Vector2(card.size.x * scale_factor, card.size.y * scale_factor)
	card.position = (slot_size - card_drawn_size) / 2
	card.disabled = false

	# Notify listeners about this slot changing
	emit_signal("card_changed", card_ui)
	# Debug – after placing incoming card, verify what the slot now contains
	var card_id := -1
	if is_instance_valid(card_ui):
		card_id = card_ui.get_instance_id()
	print("[CardSlot] slot %d AFTER PLACE → %s (CardUI id: %d)" % [get_index(), _debug_card_name(card_ui), card_id])

	# === Handle the outgoing card if there was one ===
	if outgoing and outgoing != card:
		var dest_parent: Control = null
		# If we dragged from another CardSlot, swap the cards
		if incoming_prev_parent is CardSlot:
			dest_parent = incoming_prev_parent
			# Update the other slot's reference and visuals
			(incoming_prev_parent as CardSlot).card_ui = outgoing
			outgoing.reparent(dest_parent)
			var other_size := dest_parent.get_size()
			var other_scale: float = min(other_size.x / outgoing.size.x, other_size.y / outgoing.size.y)
			outgoing.scale = Vector2.ONE * other_scale
			var outgoing_drawn_size: Vector2 = Vector2(outgoing.size.x * other_scale, outgoing.size.y * other_scale)
			outgoing.position = (other_size - outgoing_drawn_size) / 2
			# Re-enable the outgoing card so it can be interacted with in its new slot
			outgoing.disabled = false
			var other_slot := outgoing.get_parent() as CardSlot
			var outgoing_name := _debug_card_name(outgoing)
			print("[CardSlot] SWAP: slot %d now → %s | slot %d now → %s" % [get_index(), incoming_card_name, other_slot.get_index(), outgoing_name])
			(outgoing.get_parent() as CardSlot).emit_signal("card_changed", outgoing)
		else:
			# Default: send the outgoing card back to its original hand (stored in outgoing.parent)
			if outgoing.parent and is_instance_valid(outgoing.parent):
				dest_parent = outgoing.parent
			else:
				dest_parent = incoming_prev_parent  # Fallback
			outgoing.reparent(dest_parent)
			# Maintain ordering in the hand by moving to original index
			if dest_parent and dest_parent is Control:
				var new_index := clampi(outgoing.original_index, 0, dest_parent.get_child_count())
				dest_parent.move_child.call_deferred(outgoing, new_index)
			outgoing.scale = Vector2.ONE
			outgoing.disabled = false
			var out_name := _debug_card_name(outgoing)
			print("[CardSlot] slot %d RETURN → %s" % [get_index(), out_name])

		# Outgoing card's slot (if any) already emitted its signal above, no need for extra emit.

func clear() -> void:
	if card_ui and is_instance_valid(card_ui):
		card_ui.queue_free()
	card_ui = null
	emit_signal("card_changed", null)
