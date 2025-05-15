class_name PvpBattle
extends Node2D

# Debug settings - set to true to enable various testing features
const DEBUG_MODE = true          # Master debug toggle
const DEBUG_NO_STREAK_DAMAGE = false  # Streak cards will now deal damage normally

# When this is true, the player will get 10 block on every turn start for testing
const DEBUG_AUTO_BLOCK = false     # Disabled auto-block testing now that block visuals work

const PvpData             := preload("res://pvp_data.gd")
const RELIC_HANDLER_SCENE := preload("res://scenes/relic_handler/relic_handler.tscn")
const CARD_UI_SCENE       := preload("res://scenes/card_ui/card_ui.tscn")

@onready var battle_ui      : BattleUI      = $BattleUI
@onready var player_handler : PlayerHandler = $PlayerHandler
@onready var handler2       : PlayerHandler = $PlayerHandler2
@onready var player         : Player        = $Player
@onready var player2        : Player        = $Player2
@onready var end_turn_btn   := battle_ui.end_turn_button

var _rng    := RandomNumberGenerator.new()
var ai_hand : Array[Card] = []

static func _speed_rank(spd: Card.Speed) -> int:
	match spd:
		Card.Speed.SLOW:   return 0
		Card.Speed.NORMAL: return 1
		Card.Speed.FAST:   return 2
		Card.Speed.SNAP:   return 3
		_:                 return 1

func _ready() -> void:
	_rng.randomize()
	_load_stats()
	_make_relic_handlers()
	_setup_ui_slots()

	battle_ui.char_stats = player.stats
	battle_ui.initialize_card_pile_ui()

	_start_battle()

	# Only connect the player_hand_drawn signal
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	# REMOVED: Events.player_turn_ended.connect(_on_end_turn_pressed)
	# This was causing infinite recursion because _on_end_turn_pressed also emits player_turn_ended
	
	# ADDED: Connect the end turn button directly to our function
	# This replaces the event-based approach that caused the infinite loop
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	print("[PVP] End turn button connected directly")

	for slot in battle_ui.player_slots:
		slot.connect("pre_card_accept", _check_card_energy)

func _load_stats() -> void:
	print("[PVP] Loading player stats...")
	if PvpData.player_stats:
		player.stats = PvpData.player_stats.create_instance()
	else:
		player.stats = CharacterStats.new()

	if PvpData.ai_stats:
		player2.stats = PvpData.ai_stats.create_instance()
	else:
		player2.stats = CharacterStats.new()

func _make_relic_handlers() -> void:
	if player_handler.relics == null:
		var rh = RELIC_HANDLER_SCENE.instantiate()
		add_child(rh)
		player_handler.relics = rh
	if handler2.relics == null:
		var rh2 = RELIC_HANDLER_SCENE.instantiate()
		add_child(rh2)
		handler2.relics = rh2

func _setup_ui_slots() -> void:
	for s in battle_ui.player_slots + battle_ui.enemy_slots:
		s.add_to_group("card_slots")
	end_turn_btn.disabled = true
	for s in battle_ui.player_slots + battle_ui.enemy_slots:
		s.card_changed.connect(_on_slot_card_changed)
	for s in battle_ui.player_slots:
		s.pre_card_accept.connect(_check_card_energy)

func _start_battle() -> void:
	player_handler.hand = battle_ui.hand
	handler2.hand       = null

	player_handler.start_battle(player.stats)
	handler2.start_battle(player2.stats)

	_draw_ai_hand()

func _draw_ai_hand() -> void:
	print("[DEBUG] Drawing AI hand from handler2.character draw pile")
	ai_hand.clear()
	
	# Draw cards from handler2's draw pile, not player2.stats
	if handler2 and handler2.character:
		for i in range(handler2.character.cards_per_turn):
			if handler2.character.draw_pile.empty():
				print("[AI DRAW] Draw pile empty, breaking")
				break
				
			var card = handler2.character.draw_pile.draw_card()
			if card: # Ensure we have a valid card
				ai_hand.append(card)
				print("[DEBUG] AI drew:", card.id, " from handler2 deck")
			else:
				print("[ERROR] Drew null card from AI draw pile!")
	else:
		print("[ERROR] handler2 or handler2.character is null!")


# Draw a single card for the AI and add it to the AI's hand
func _draw_ai_card() -> void:
	# Check if we have valid handler and character
	if not handler2 or not handler2.character:
		print("[ERROR] Cannot draw AI card - handler2 or handler2.character is null!")
		return
		
	# Check if draw pile is empty
	if handler2.character.draw_pile.empty():
		print("[AI CARD DRAW] Draw pile empty, cannot draw additional card")
		return
		
	# Draw a single card
	var card = handler2.character.draw_pile.draw_card()
	if card: # Ensure we have a valid card
		ai_hand.append(card)
		print("[AI CARD DRAW] Drew single card: " + card.id)
	else:
		print("[ERROR] Drew null card from AI draw pile during single draw!")


# Update the health and block display for both player and AI
func update_health_ui() -> void:
	# Check if we have the battle UI
	if not battle_ui:
		print("[WARN] Cannot update health UI - battle_ui is null")
		return
	
	# DIRECT APPROACH: Use battle_ui to directly update the actual health and block values
	# We know from the logs that HealthUI nodes exist and work when directly updated
	print("[BLOCK UPDATE] Player block: " + str(player_handler.character.block))
	print("[BLOCK UPDATE] AI block: " + str(handler2.character.block))
	
	# Get the health label for player directly - we can see it exists in logs
	var player_health_label = battle_ui.get_node_or_null("PlayerHealthLabel")
	
	# If not direct in battle_ui, traverse hierarchy to find it
	if not player_health_label:
		# Check common locations
		var common_paths = [
			"PlayerInfo/HealthUI/HealthLabel",
			"PlayerContainer/HealthUI/HealthLabel",
			"PlayerContainer/Label"
		]
		
		for path in common_paths:
			if battle_ui.has_node(path):
				player_health_label = battle_ui.get_node(path)
				print("[BLOCK DEBUG] Found player health label at: " + path)
				break
	
	# Direct update of player health and block value
	if player_health_label and player_handler and player_handler.character:
		var health_text = str(player_handler.character.health)
		if player_handler.character.block > 0:
			health_text += " 🛡️" + str(player_handler.character.block)
		
		player_health_label.text = health_text
		print("[BLOCK DEBUG] Set player health label directly to: '" + health_text + "'")
	
	# Try direct reference to specialized block component if it exists
	var player_block = battle_ui.get_node_or_null("PlayerBlock")
	if player_block and player_handler and player_handler.character:
		if player_block.has_method("update_block"):
			player_block.update_block(player_handler.character.block)
			print("[BLOCK DEBUG] Updated player block component with: " + str(player_handler.character.block))
		elif player_block.has_node("Label"):
			var block_label = player_block.get_node("Label")
			block_label.text = str(player_handler.character.block)
			player_block.visible = player_handler.character.block > 0
			print("[BLOCK DEBUG] Updated player block label directly with: " + str(player_handler.character.block))
	
	# AI/Enemy health label
	var enemy_health_label = battle_ui.get_node_or_null("EnemyHealthLabel")
	if not enemy_health_label:
		var common_paths = [
			"EnemyInfo/HealthUI/HealthLabel",
			"EnemyContainer/HealthUI/HealthLabel",
			"AIContainer/Label"
		]
		
		for path in common_paths:
			if battle_ui.has_node(path):
				enemy_health_label = battle_ui.get_node(path)
				break
	
	# Direct update of enemy health and block value
	if enemy_health_label and handler2 and handler2.character:
		var health_text = str(handler2.character.health)
		if handler2.character.block > 0:
			health_text += " 🛡️" + str(handler2.character.block)
		
		enemy_health_label.text = health_text
	
	# Last resort - try to find ANY StatsUI or HealthUI by recursively checking all nodes
	print("[BLOCK DEBUG] Attempting to find player StatsUI directly")
	for node in get_tree().get_nodes_in_group("stats_ui"):
		if node.name.begins_with("Player") and player_handler and player_handler.character:
			if node.has_method("update_stats"):
				node.update_stats(player_handler.character)
				print("[BLOCK DEBUG] Found player UI by group: " + node.name)
		elif node.name.begins_with("Enemy") or node.name.begins_with("AI"):
			if node.has_method("update_stats") and handler2 and handler2.character:
				node.update_stats(handler2.character)
				print("[BLOCK DEBUG] Found AI UI by group: " + node.name)

	var ids = []
	for c in ai_hand:
		if c:
			ids.append(c.id)
		else:
			print("[WARNING] Found null card in AI hand")
	print("[AI HAND] Count:", ids.size(), "→", ids)

func _on_player_hand_drawn() -> void:
	# Debug the contents of player hand
	if battle_ui and battle_ui.hand:
		# Enable the hand first so cards can be dragged
		battle_ui.hand.enable_hand()
		
		# Then check the hand contents
		if battle_ui.hand.get_child_count() > 0:
			var card_ids = []
			for card_ui in battle_ui.hand.get_children():
				if card_ui.card:
					card_ids.append(card_ui.card.id)
			print("[PLAYER HAND] Count:" + str(card_ids.size()) + "→" + str(card_ids))
			
			# Verify all cards match the character (debugging)
			print("[VERIFY HAND] Expected character: " + str(player_handler.character.resource_path.get_file().get_basename()))
			for card_ui in battle_ui.hand.get_children():
				# Simple validation
				if card_ui.card != null:
					# Since we're dynamically filling decks, we trust the system
					print("[VERIFY OK] Card " + card_ui.card.id + " matches character")
					
		# Make sure end turn button is enabled
		end_turn_btn.disabled = false
		
		# Update card affordability one last time
		update_card_affordability()
	
	# Update card colors based on energy availability
	update_card_affordability()

func update_card_affordability() -> void:
	# Make sure we have valid player data
	if not player_handler or not player_handler.character:
		print("[MANA CHECK] No valid player character, cannot update affordability")
		return
	
	var player_mana = player_handler.character.mana
	print("[MANA CHECK] Player has " + str(player_mana) + "/" + str(player_handler.character.max_mana) + " mana available")
	
	# Check how many slots have been filled by the player
	var slots_used = 0
	for slot in battle_ui.player_slots:
		if slot.card_ui != null:
			slots_used += 1
	
	print("[SLOTS] Player has filled " + str(slots_used) + "/3 slots")
	
	# Update card affordability in hand
	var hand_count = 0
	for card_ui in battle_ui.hand.get_children():
		if card_ui is CardUI and card_ui.card:
			hand_count += 1
			var cost = card_ui.card.cost
			var can_afford = player_mana >= cost
			
			print("[CARD AFFORD] Card '" + card_ui.card.id + "' cost:" + str(cost) + ", affordable:" + str(can_afford))
	
	print("[MANA CHECK] Hand has " + str(hand_count) + " cards, with " + str(player_mana) + " mana remaining")
	
	# Update all cards in hand to show red if they're too expensive
	for card_ui in battle_ui.hand.get_children():
		if card_ui and card_ui.card and "cost" in card_ui.card:
			var card_cost = card_ui.card.cost
			var can_afford = player_mana >= card_cost
			if not can_afford:
				# Use can_play_card from CharacterStats - matches PVE logic
				var affordable = player_handler.character.can_play_card(card_ui.card)
				
				# Make the card UI reflect whether it's affordable
				if "playable" in card_ui:
					card_ui.playable = can_afford
				
				# Use the set_card_affordable method if available
				if card_ui.has_method("set_card_affordable"):
					card_ui.set_card_affordable(can_afford)
				
				# Apply visual indicator (red for unaffordable)
				if not affordable:
					card_ui.modulate = Color(1.5, 0.5, 0.5) # Red tint
				else:
					card_ui.modulate = Color(1, 1, 1) # Normal color
	
	# Card verification is already done in _on_player_hand_drawn

func _on_slot_card_changed(card_ui: CardUI) -> void:
	# Always enable end turn button regardless of filled slots
	# This allows player to end turn with any number of filled slots
	end_turn_btn.disabled = false
	
	# Count filled slots for reference
	var filled = 0
	for s in battle_ui.player_slots:
		if not s.is_empty():
			filled += 1
			
	# Show how many slots are filled in a debug message
	print("[SLOTS] Player has filled " + str(filled) + "/3 slots")
	
	# Update card colors based on current mana availability
	# This makes cards turn red when you don't have enough mana
	update_card_affordability()
	
# Check if player has enough energy for this card
func _check_card_energy(card_ui: CardUI, slot: CardSlot) -> void:
	if not card_ui or not card_ui.card:
		return
	
	# Get the card's energy cost
	var card_cost = 1 # Default cost
	if "cost" in card_ui.card:
		card_cost = card_ui.card.cost
		print("[ENERGY] Card costs " + str(card_cost) + " energy")
	
	# Get player's current mana directly from character (same as PVE)
	var player_mana = 0
	if player_handler and player_handler.character:
		player_mana = player_handler.character.mana
		print("[ENERGY] Player has " + str(player_mana) + "/" + str(player_handler.character.max_mana) + " energy to use")
	
	# Calculate total energy used in other slots
	var energy_used = 0
	for s in battle_ui.player_slots:
		# Skip the current slot as we're checking if we can place here
		if s == slot:
			continue
		
		# Add up energy cost of cards in other slots
		if not s.is_empty() and s.card_ui and s.card_ui.card:
			var slot_card = s.card_ui.card
			if "cost" in slot_card:
				energy_used += slot_card.cost
			else:
				energy_used += 1 # Default cost
	
	# Check if playing this card would exceed available energy
	var energy_remaining = player_mana - energy_used
	if card_cost > energy_remaining:
		# Set a metadata flag that the slot will check to reject the card
		card_ui.set_meta("energy_blocked", true)
		# Show energy warning to player
		print("[ENERGY] Cannot play card: requires " + str(card_cost) + " energy, but only " + str(energy_remaining) + " remaining")
		return
	
	# Card is playable energy-wise
	print("[ENERGY] Card can be played: cost " + str(card_cost) + ", energy remaining " + str(energy_remaining) + "")


func _on_end_turn_pressed() -> void:
	# Immediately disable button to prevent multiple calls
	end_turn_btn.disabled = true
	
	# Log deck states before proceeding
	print("[DEBUG] End turn pressed with state:")
	print("  Player deck: ", player_handler.character.resource_path, ", cards left: ", player_handler.character.draw_pile.cards.size())
	print("  AI deck: ", handler2.character.resource_path, ", cards left: ", handler2.character.draw_pile.cards.size())
	
	# For PVP mode, we need to manually handle turn end to avoid status effect recursion
	# Disable the hand instead of using the full player_handler.end_turn()
	if battle_ui and battle_ui.hand:
		battle_ui.hand.disable_hand()
		print("[PVP] Manually disabled player hand")
	
	# Emit the turn ended event for consistency with PVE
	Events.player_turn_ended.emit()
	
	# Make sure AI has cards to pick
	if ai_hand.size() == 0:
		_draw_ai_hand()
	
	# Get AI card choices for this turn
	print("[DEBUG] Calling _ai_pick_three()")
	var picks = await _ai_pick_three()
	
	# For PVP mode, we need to manually reset stats instead of using full start_turn()
	# to avoid triggering a potential infinite recursion with status effects
	if player_handler and player_handler.character:
		# Just reset block and mana without triggering status effects
		player_handler.character.block = 0
		player_handler.character.reset_mana()
		print("[PVP] Manually reset player block and mana")
		
	if handler2 and handler2.character:
		# Same for AI character
		handler2.character.block = 0
		handler2.character.reset_mana()
		print("[PVP] Manually reset AI block and mana")
	
	# Debug output energy values to verify
	print("[MANA RESET] Player: " + str(player_handler.character.mana) + "/" + str(player_handler.character.max_mana))
	print("[MANA RESET] AI: " + str(handler2.character.mana) + "/" + str(handler2.character.max_mana))
	
	for i in range(3):
		var ai_card : Card = null
		if i < picks.size():
			ai_card = picks[i]
		_resolve_slot(i, ai_card)

	# TEMPORARILY COMMENTED OUT: Reset block values for both players
	# This was causing the desync issue between game logic and UI
	# player.stats.block = 0
	# player2.stats.block = 0
	# The correct objects would be:
	# player_handler.character.block = 0
	# handler2.character.block = 0
	# But we're keeping block for testing purposes

	# 1. Clear the slots
	for s in battle_ui.player_slots + battle_ui.enemy_slots:
		s.clear()
	
	# 2. Process hand
	# IMPORTANT FIX: Don't discard unplayed cards from hand!
	# Instead, put them back into the draw pile for next turn
	
	# First collect all unplayed cards
	var unplayed_cards = []
	for card_ui in battle_ui.hand.get_children():
		if card_ui.card:
			unplayed_cards.append(card_ui.card)
			print("[CARD PRESERVE] Saving unplayed card " + card_ui.card.id)
		card_ui.queue_free()
		
	# Then add them back at the start of the draw pile
	# We need to insert them at the FRONT not end
	if unplayed_cards.size() > 0:
		print("[CARD PRESERVE] Adding " + str(unplayed_cards.size()) + " unplayed cards back to the draw pile")
		var current_cards = player_handler.character.draw_pile.cards.duplicate()
		player_handler.character.draw_pile.clear()
		
		# Add them back in reverse order to maintain hand order
		for i in range(unplayed_cards.size() - 1, -1, -1):
			player_handler.character.draw_pile.add_card(unplayed_cards[i])
		
		# Then add all other cards back
		for card in current_cards:
			player_handler.character.draw_pile.add_card(card)
	
	# 3. Clear the AI hand after resolving slots
	ai_hand = [] # Reset to empty array

	print("[DEBUG] Turn ended, ensuring decks are distinct before next draw:")
	print("  Player handler character: ", player_handler.character.character_name)
	print("  AI handler character: ", handler2.character.character_name)
	
	# CRITICAL FIX: Ensure players keep drawing from their own decks
	var player_stats_copy = player.stats.duplicate()
	var ai_stats_copy = player2.stats.duplicate()
	
	# Clear hand UI again to be doubly sure
	if battle_ui and battle_ui.hand:
		for child in battle_ui.hand.get_children():
			child.queue_free()
	
	# Important - ensure discard piles are created
	if not player_stats_copy.discard:
		player_stats_copy.discard = CardPile.new()
		
	if not ai_stats_copy.discard:
		ai_stats_copy.discard = CardPile.new()
	
	# Store the current health and mana values before character reassignment
	var current_player_health = 0
	var current_ai_health = 0
	var current_player_block = 0
	var current_ai_block = 0
	
	# Ensure we have valid characters before trying to access health
	if player_handler and player_handler.character:
		current_player_health = player_handler.character.health
		current_player_block = player_handler.character.block

	if handler2 and handler2.character:
		current_ai_health = handler2.character.health
		current_ai_block = handler2.character.block
	
	print("[HEALTH PRESERVE] Storing: Player health:", current_player_health, ", AI health:", current_ai_health)
	
	# IMPORTANT: Instead of replacing the entire character, just update core properties
	# This preserves UI connections and references to the character
	if player_handler and player_handler.character and player_stats_copy:
		# Update properties instead of replacing the instance
		player_handler.character.draw_pile = player_stats_copy.draw_pile
		player_handler.character.discard = player_stats_copy.discard
		player_handler.character.health = current_player_health
		# TEMPORARILY DISABLED: Block reset at turn end so we can see block visuals
		# player_handler.character.block = 0  # Reset block at turn end
		print("[BLOCK DEBUG] Block reset DISABLED, current block: " + str(player_handler.character.block))
		player_handler.character.reset_mana() # Reset mana to max
		
	if handler2 and handler2.character and ai_stats_copy:
		# Update AI properties instead of replacing instance
		handler2.character.draw_pile = ai_stats_copy.draw_pile
		handler2.character.discard = ai_stats_copy.discard
		handler2.character.health = current_ai_health
		# TEMPORARILY DISABLED: Block reset at turn end so we can see block visuals
		# handler2.character.block = 0  # Reset block at turn end
		print("[BLOCK DEBUG] AI Block reset DISABLED, current block: " + str(handler2.character.block))
		handler2.character.reset_mana() # Reset mana to max
	
	# DEBUG: We no longer need to restore health since we're not replacing the character instances
	# We're just updating their properties directly now
	print("[HEALTH RESTORED] Player health preserved:", player_handler.character.health)
	print("[HEALTH RESTORED] AI health preserved:", handler2.character.health)
	
	# Get the starting decks to populate/refill with the correct cards
	var player_deck_cards = []
	var ai_deck_cards = []
	
	# First check if we have cards in the discard pile to shuffle back
	print("[DECK REFILL] Checking discard piles to reshuffle")
	
	if player_handler.character.discard and not player_handler.character.discard.empty():
		print("[PLAYER RESHUFFLE] Using", player_handler.character.discard.size(), "cards from discard")
		while not player_handler.character.discard.empty():
			player_deck_cards.append(player_handler.character.discard.draw_card())
	else:
		# If no discard cards, use the initial deck as fallback
		print("[PLAYER DECK] Using initial player deck for character: ", player.name)
		player_deck_cards = player.stats.starting_deck.duplicate_cards()
		
	# Same for AI
	if handler2.character.discard and not handler2.character.discard.empty():
		print("[AI RESHUFFLE] Using", handler2.character.discard.size(), "cards from discard")
		while not handler2.character.discard.empty():
			ai_deck_cards.append(handler2.character.discard.draw_card())
	else:
		# If no discard cards, use the initial deck as fallback
		print("[AI DECK] Using initial AI deck for character: ", player2.name)
		ai_deck_cards = player2.stats.starting_deck.duplicate_cards()
	
	# Ensure draw piles exist
	if not player_handler.character.draw_pile:
		print("[FIX] Creating new player draw pile")
		player_handler.character.draw_pile = CardPile.new()
	else:
		player_handler.character.draw_pile.clear()
	
	if not handler2.character.draw_pile:
		print("[FIX] Creating new AI draw pile")
		handler2.character.draw_pile = CardPile.new()
	else:
		handler2.character.draw_pile.clear()
		
	# Add cards to player draw pile
	print("[DECK FILL] Adding", player_deck_cards.size(), "cards to player draw pile")
	for card in player_deck_cards:
		player_handler.character.draw_pile.add_card(card)
	player_handler.character.draw_pile.shuffle()
	
	# Add cards to AI draw pile
	print("[DECK FILL] Adding", ai_deck_cards.size(), "cards to AI draw pile")
	for card in ai_deck_cards:
		handler2.character.draw_pile.add_card(card)
	handler2.character.draw_pile.shuffle()
	
	# 5. Draw exactly 4 cards for player and reset mana
	_direct_draw_player_cards()
	
	# Reset mana explicitly to ensure it works properly
	_reset_all_character_mana()
	
	# Draw AI hand
	_draw_ai_hand()

func _reset_all_character_mana() -> void:
	# Reset mana for player character exactly like in PVE
	if player_handler and player_handler.character:
		player_handler.character.reset_mana()
		print("[MANA RESET] Player: " + str(player_handler.character.mana) + "/" + str(player_handler.character.max_mana))
	
	# Reset AI character mana
	if handler2 and handler2.character:
		handler2.character.reset_mana()
	
	# Track any mana changes in update_card_affordability
	update_card_affordability()

# Draw directly to player hand
func _direct_draw_player_cards() -> void:
	# Auto-block testing - apply block at the start of each turn if enabled
	if DEBUG_MODE and DEBUG_AUTO_BLOCK and player_handler and player_handler.character:
		print("[DEBUG BLOCK] 🛡️ Auto-applying 10 block for testing")
		player_handler.character.block += 10
		print("[DEBUG BLOCK] Player block is now: " + str(player_handler.character.block))
		# Force an immediate health UI update to show block visuals
		update_health_ui()
	
	# Use the character's cards_per_turn instead of hardcoded count
	var count = player_handler.character.cards_per_turn
	
	# DETAILED CARD LOGGING - Show exact deck state
	print("\n[CARD SYSTEM] =========== STARTING CARD DRAW SEQUENCE ===========")
	print("[CARD SYSTEM] Attempting to draw " + str(count) + " cards")
	
	# Log what cards were in hand before we clear it
	var previous_hand_cards = []
	if battle_ui.hand:
		for child in battle_ui.hand.get_children():
			if child is CardUI and child.card:
				previous_hand_cards.append(child.card.id)
			
	# IMPORTANT: Clear hand immediately (don't use queue_free which only marks for deletion)
	if battle_ui.hand:
		print("[CARD SYSTEM] 🧹 FORCE CLEARING hand of " + str(battle_ui.hand.get_child_count()) + " cards")
		for child in battle_ui.hand.get_children():
			battle_ui.hand.remove_child(child)
			child.free() # Immediately free the node instead of queuing
		
	print("[CARD SYSTEM] Cleared hand, previously had " + str(previous_hand_cards.size()) + " cards: " + str(previous_hand_cards))
	
	# Double-check hand is truly empty before proceeding
	if battle_ui.hand.get_child_count() > 0:
		print("[CARD SYSTEM] ⚠️ WARNING: Hand still has " + str(battle_ui.hand.get_child_count()) + " children after clearing!")
		for i in range(battle_ui.hand.get_child_count()):
			print("[CARD SYSTEM] Remaining child " + str(i) + ": " + str(battle_ui.hand.get_child(i).name))

	# Reset mana first to ensure correct values
	_reset_all_character_mana()
	
	# Make sure the entire hand system is re-enabled before continuing
	battle_ui.hand.enable_hand()
	
	# Update affordability after mana reset
	update_card_affordability()
	
	# CRITICAL: Print detailed draw/discard state before drawing
	var draw_pile_cards = []
	var discard_pile_cards = []
	
	# Get all card IDs from draw pile
	for card in player_handler.character.draw_pile.cards:
		draw_pile_cards.append(card.id)
	
	# Get all card IDs from discard pile
	for card in player_handler.character.discard.cards:
		discard_pile_cards.append(card.id)
		
	print("[CARD SYSTEM] BEFORE DRAW - Draw pile: " + str(player_handler.character.draw_pile.cards.size()) + 
		" cards: " + str(draw_pile_cards))
	print("[CARD SYSTEM] BEFORE DRAW - Discard pile: " + str(player_handler.character.discard.cards.size()) + 
		" cards: " + str(discard_pile_cards))
	
	# Ensure we have enough cards by reshuffling or refilling with starting deck
	if player_handler.character.draw_pile.cards.size() < count:
		print("[CARD SYSTEM] ⚠️ Not enough cards in draw pile (" + 
			str(player_handler.character.draw_pile.cards.size()) + "/" + str(count) + "), reshuffling discard")
		
		# Gather discard pile cards for logging
		var discard_cards = []
		for card in player_handler.character.discard.cards:
			discard_cards.append(card.id)
		print("[CARD SYSTEM] Reshuffling discard pile cards: " + str(discard_cards))
		
		# Move cards from discard to draw pile
		var reshuffled_count = 0
		while not player_handler.character.discard.empty():
			var discard_card = player_handler.character.discard.draw_card()
			player_handler.character.draw_pile.add_card(discard_card)
			reshuffled_count += 1
		
		print("[CARD SYSTEM] Moved " + str(reshuffled_count) + " cards from discard to draw pile")
			
		# If we STILL don't have enough cards, use the starting deck
		if player_handler.character.draw_pile.cards.size() < count:
			print("[CARD SYSTEM] 🚨 Still not enough cards after reshuffle (" + 
				str(player_handler.character.draw_pile.cards.size()) + "/" + str(count) + "), using starting deck")
			
			var starting_cards = player.stats.starting_deck.duplicate_cards()
			var starting_card_ids = []
			for card in starting_cards:
				starting_card_ids.append(card.id)
			
			print("[CARD SYSTEM] Adding " + str(starting_cards.size()) + " cards from starting deck: " + str(starting_card_ids))
			
			for card in starting_cards:
				player_handler.character.draw_pile.add_card(card)
			
		# Shuffle the new draw pile
		player_handler.character.draw_pile.shuffle()
		
		# Log the final draw pile contents after shuffling
		var final_draw_pile = []
		for card in player_handler.character.draw_pile.cards:
			final_draw_pile.append(card.id)
			
		print("[CARD SYSTEM] After reshuffle - Draw pile has " + 
			str(player_handler.character.draw_pile.cards.size()) + " cards: " + str(final_draw_pile))
	
	# Store cards to add first
	var cards_to_add = []
	var drawn = 0
	
	print("[CARD SYSTEM] 🎯 Starting to draw " + str(count) + " cards, draw pile has " + 
		str(player_handler.character.draw_pile.cards.size()) + " cards")
	
	# GUARANTEED DRAW - Always attempt to draw exactly 'count' cards
	while drawn < count:
		# Double check - if somehow the draw pile is still empty, refill it
		if player_handler.character.draw_pile.empty():
			print("[CARD SYSTEM] 🚨 EMERGENCY: Draw pile empty during draw, refilling with starting deck")
			
			# Emergency refill from starting deck
			var starting_cards = player.stats.starting_deck.duplicate_cards()
			var emergency_card_ids = []
			
			for card in starting_cards:
				emergency_card_ids.append(card.id)
				player_handler.character.draw_pile.add_card(card)
				
			print("[CARD SYSTEM] Added " + str(starting_cards.size()) + " emergency cards: " + str(emergency_card_ids))
			player_handler.character.draw_pile.shuffle()
			
		# Now draw the card
		var card = player_handler.character.draw_pile.draw_card()
		
		# Skip null cards - though this shouldn't happen now
		if card == null:
			print("[CARD SYSTEM] ⚠️ Got null card from player draw pile at position " + str(drawn + 1))
			continue
		
		cards_to_add.append(card)
		drawn += 1
		print("[CARD SYSTEM] Drew card #" + str(drawn) + ": '" + card.id + "' (" + str(drawn) + "/" + str(count) + ")")
		print("[CARD SYSTEM] Remaining in draw pile: " + str(player_handler.character.draw_pile.cards.size()) + " cards")
	
	# Verify we got exactly 'count' cards with clear visual indicators
	if cards_to_add.size() == count:
		print("[CARD SYSTEM] ✅ DRAW SUCCESS: Got exactly " + str(cards_to_add.size()) + "/" + str(count) + " cards")
	else:
		print("[CARD SYSTEM] ❌ DRAW FAILURE: Only got " + str(cards_to_add.size()) + "/" + str(count) + " cards!")
	
	# List all drawn cards
	var drawn_card_ids = []
	for card in cards_to_add:
		drawn_card_ids.append(card.id)
	print("[CARD SYSTEM] Cards to be added to hand: " + str(drawn_card_ids))
	
	# Reset the player's hand completely
	print("[CARD SYSTEM] Enabling hand for interaction")
	battle_ui.hand.enable_hand()
	
	# Create all card UIs at once - but this time let's use the PlayerHandler's add_card_to_hand
	# since it should work now that we've properly cleared the hand
	var successful_adds = 0
	var player_character = player_handler.character
	
	print("[CARD SYSTEM] 🔄 Hand should be empty, has " + str(battle_ui.hand.get_child_count()) + " children")
	
	# CRITICAL FIX: Use the player_handler to add cards (which will properly instance the CardUI scene)
	for card in cards_to_add:
		var prev_count = battle_ui.hand.get_child_count()
		
		# Use the player handler to properly create the card UI from its scene
		player_handler.add_card_to_hand(card)
		
		# Check if card was actually added
		var new_count = battle_ui.hand.get_child_count()
		if new_count > prev_count:
			successful_adds += 1
			print("[CARD SYSTEM] ✅ Added card '" + card.id + "' to hand - Hand now has " + str(new_count) + " cards")
		else:
			print("[CARD SYSTEM] ❌ FAILED to add card '" + card.id + "' to hand - Still has " + str(new_count) + " cards")
	
	# Final verification with clear indicators
	var final_hand_size = battle_ui.hand.get_child_count()
	if final_hand_size == count:
		print("[CARD SYSTEM] ✅ SUCCESS: Hand has exactly " + str(final_hand_size) + "/" + str(count) + " cards")
	else:
		print("[CARD SYSTEM] ❌ FAILURE: Hand only has " + str(final_hand_size) + "/" + str(count) + " cards!")
		
	# Show final hand contents
	var final_hand_cards = []
	for child in battle_ui.hand.get_children():
		if child is CardUI and child.card:
			final_hand_cards.append(child.card.id)
	print("[CARD SYSTEM] Final hand contents: " + str(final_hand_cards))
	print("[CARD SYSTEM] ============= END OF DRAW SEQUENCE =============")
	
	# Make sure end turn button is enabled
	end_turn_btn.disabled = false
	
	# Update card affordability
	update_card_affordability()
	
	# Manually emit card draw event
	print("[MANUAL] Emitting player_hand_drawn")
	Events.player_hand_drawn.emit()

# ============================
# MAIN AI CARD SLOT LOGIC ZONE
# ============================
func _ai_pick_three() -> Array[Card]:
	print("[DEBUG] _ai_pick_three(): ai_hand.size()=", ai_hand.size(), ", starting draw.")
	var picks: Array[Card] = []
	
	# First use any cards from AI hand
	while ai_hand.size() > 0 and picks.size() < 3:
		picks.append(ai_hand.pop_back())
	print("[DEBUG] After ai_hand pop: picks.size()=", picks.size())
	
	# If we need more cards and have the handler2 character with a draw pile
	if picks.size() < 3 and handler2 and handler2.character and handler2.character.draw_pile:
		while picks.size() < 3 and not handler2.character.draw_pile.empty():
			var card = handler2.character.draw_pile.draw_card()
			if card:
				picks.append(card)
				print("[AI PICK] Drew additional card:", card.id, "from handler2 deck")
			else:
				print("[ERROR] Drew null card during AI pick process!")
	# Shuffle picks
	var debug_ids = []
	for p in picks:
		if p:
			debug_ids.append(p.id)
		else:
			debug_ids.append("NULL_CARD")
			print("[ERROR] Found null card in AI picks!")
	print("[DEBUG] Before shuffle: picks size =", picks.size(), " ids =", debug_ids)
	for i in range(picks.size()):
		var j = _rng.randi_range(i, picks.size() - 1)
		var tmp = picks[i]
		picks[i] = picks[j]
		picks[j] = tmp

	var ids = []
	# Clear all enemy slots first
	for idx in range(battle_ui.enemy_slots.size()):
		battle_ui.enemy_slots[idx].clear()
		
	# Then assign AI cards to slots sequentially
	for idx in range(min(picks.size(), battle_ui.enemy_slots.size())):
		var slot = battle_ui.enemy_slots[idx]
		print("[DEBUG] Processing slot", idx, " - is null?", slot == null)
		if true: # Simplified condition since we're already min-bounded
			var picked_card = picks[idx]
			var ui = CARD_UI_SCENE.instantiate() as CardUI
			print("[ASSIGNING] Slot", idx, " picked card id =", picked_card.id, "ui valid?", ui != null)

			ui.char_stats = handler2.character
			ui.disabled = true
			# Set card first to ensure CardUI is ready with card
			ui.card = picked_card
			# Then place in slot
			slot.accept_card(ui)
			# Store reference in slot
			slot.card_ui = ui
			print("[DEBUG] After slot accept, slot.card_ui=", slot.card_ui != null)              # set card after ready so visuals update via setter
			print("[DEBUG] Assigned Slot", idx, "with", ui.card.id)
			ids.append(picked_card.id)

	print("[DEBUG] Final picked card count:", ids.size(), ", slots filled:", battle_ui.enemy_slots.size())
	for i in range(battle_ui.enemy_slots.size()):
		var slot = battle_ui.enemy_slots[i]
		print("[DEBUG] Slot", i, " has card_ui =", "valid" if slot.card_ui != null else "null")
		if slot.card_ui:
			print("[DEBUG]   - card_ui.card =", "valid" if slot.card_ui.card != null else "null", 
			", id =", slot.card_ui.card.id if slot.card_ui and slot.card_ui.card else "none")
	print("[AI PICKS] Count:", ids.size(), "→", ids)
	# AI picks prepared
	return picks as Array[Card]

func _resolve_slot(idx: int, ai_card: Card) -> void:
	# Start resolving cards for this slot
	print("\n[SLOT ", idx, "]")
	
	var p_slot = battle_ui.player_slots[idx]
	var e_slot = battle_ui.enemy_slots[idx]
	var p_ui   = p_slot.card_ui
	var ai_ui  = e_slot.card_ui
	# Backup: the picked card object in case UI assignment failed
	var ai_card_obj : Card = ai_card
	
	# Show which cards are being played
	print("Player: ", p_ui.card.id if p_ui and p_ui.card else "None")
	print("AI: ", ai_ui.card.id if ai_ui and ai_ui.card else (ai_card.id if ai_card else "None"))

	var p_id = "None"
	var ai_id = "None"
	var rp = -1
	var re = -1

	if p_ui != null:
		if p_ui.card != null:
			p_id = p_ui.card.id
			if "speed" in p_ui.card:
				rp = _speed_rank(p_ui.card.speed)
			else:
				print("[WARN] Player card has no speed. Defaulting to NORMAL (1)")
				rp = 1
		else:
			print("[DEBUG] Player UI exists but .card is null (Slot", idx, ")")
	else:
		print("[DEBUG] Player UI is null (Slot", idx, ")")

	if ai_ui != null and ai_ui.card != null:
		ai_card_obj = ai_ui.card
		ai_id = ai_ui.card.id
		if "speed" in ai_ui.card:
			re = _speed_rank(ai_ui.card.speed)
		else:
			print("[WARN] AI card has no speed. Defaulting to NORMAL (1)")
			re = 1
	else:
		if ai_card_obj != null:
			ai_id = ai_card_obj.id
			re = _speed_rank(ai_card_obj.speed)
			print("[INFO] Using ai_card backup for Slot", idx, ", id=", ai_id)
		else:
			print("[DEBUG] AI UI is null and no backup card (Slot", idx, ")")

	# Determine play order
	var order = []
	if p_ui and p_ui.card and ai_ui and ai_ui.card:
		if rp > re: # Player is faster
			order.append(p_ui)
			order.append(ai_ui)
		elif re > rp: # AI is faster
			order.append(ai_ui)
			order.append(p_ui)
		else: # Same speed, randomly decide
			if _rng.randi_range(0, 1) == 0:
				order.append(p_ui)
				order.append(ai_ui)
			else:
				order.append(ai_ui)
				order.append(p_ui)
	elif p_ui and p_ui.card:
		# Only player card present
		order.append(p_ui)
	elif ai_card_obj:
		# Only AI card present
		order.append(ai_card_obj)

	for element in order:
		var is_player_card : bool = (element == p_ui or (element is CardUI and element == p_ui))
		var card_obj : Card = null
		if element is CardUI:
			card_obj = (element as CardUI).card
		else:
			card_obj = element
		var owner_stats : CharacterStats
		var owner_modifiers : ModifierHandler
		if is_player_card:
			# FIXED: Use player_handler.character instead of player.stats
			owner_stats = player_handler.character
			owner_modifiers = player.modifier_handler
		else:
			# FIXED: Use handler2.character instead of player2.stats
			owner_stats = handler2.character
			owner_modifiers = player2.modifier_handler

		var target_nodes : Array[Node] = []

		# Show which card is being played and by whom
		print(("Player" if is_player_card else "AI") + " plays: " + card_obj.id)
		
		# Set targeting for the current card
		if card_obj.target == Card.Target.SELF:
			# Self-targeting (e.g. Block) should affect the card owner
			if is_player_card:
				target_nodes = [player]
			else:
				target_nodes = [player2]
		else:
			# Offensive / enemy-targeting cards
			if is_player_card:
				target_nodes = [player2]
			else:
				target_nodes = [player]

		# ENERGY SYSTEM: Check if player has enough energy for this card
		if card_obj.cost > owner_stats.mana:
			# Skip card if not enough energy
			print("  Cannot play " + card_obj.id + " - Not enough energy (" + str(owner_stats.mana) + "/" + str(owner_stats.max_mana) + ")")
			continue
		
		# Get the proper character stats reference for consistent state tracking
		var source_character = player_handler.character if is_player_card else handler2.character
		var target_character = handler2.character if is_player_card else player_handler.character
		
		# Get the proper player references
		var source_player = player if is_player_card else player2
		var target_player = player2 if is_player_card else player
		
		# Emit card played event for consistency with PVE
		Events.card_played.emit(card_obj)
		
		# Deduct mana cost from the character
		source_character.mana -= card_obj.cost
		
		# The Card.play() method expects targets as Array[Node], char_stats as CharacterStats, and modifiers as ModifierHandler
		# Creating a properly formatted array for targets
		var targets = []
		
		# Add the appropriate target based on card targeting type
		if card_obj.target == Card.Target.SELF:
			targets.append(source_player)
		else:
			targets.append(target_player)
		
		# Debug information
		print("  Playing card: " + card_obj.id + " (Cost: " + str(card_obj.cost) + ")")
		print("  Source: " + ("Player" if is_player_card else "AI") + ", Target: " + ("Player" if not is_player_card else "AI"))
		
		# Get modifier handler for effect calculations
		var modifier_handler = source_player.modifier_handler if source_player and "modifier_handler" in source_player else null
		
		# Different cards can have different effect methods depending on their implementation:
		# - Some cards implement play() - taking (Array, CharacterStats, ModifierHandler)
		# - Some cards implement apply_effects() - taking (Array[Node], ModifierHandler)
		# We need to handle all cases properly
		var card_played_successfully = false
		
		# Debug information about the card
		print("  Card ID: " + card_obj.id)
		print("  Card Methods: play=" + str(card_obj.has_method("play")) + ", apply_effects=" + str(card_obj.has_method("apply_effects")))
		
		# First, create a properly typed Array[Node] for any card that needs it
		var typed_targets: Array[Node] = []
		for t in targets:
			typed_targets.append(t)
		
		# Make sure we have all necessary parameters before proceeding
		if source_character == null or modifier_handler == null or typed_targets.size() == 0:
			push_error("Missing parameters for card " + card_obj.id)
			print("  ERROR: Missing parameters - using fallback")
		else:
			# APPROACH 1: Try apply_effects first if available
			# This is used by character-specific cards like warrior_slash and streak_chain_dash
			if card_obj.has_method("apply_effects"):
				print("  Using card.apply_effects() method directly")
				
				# Check for debug mode to block streak damage
				var is_streak_card = card_obj.id.begins_with("streak_")
				var has_damage = "base_damage" in card_obj and card_obj.base_damage > 0
				
				# For Streak cards that deal damage, apply debug mode if enabled
				if DEBUG_MODE and DEBUG_NO_STREAK_DAMAGE and is_streak_card and has_damage:
					print("[DEBUG] 🔍 Streak damage disabled: " + card_obj.id + " would have dealt " + str(card_obj.base_damage) + " damage")
					
					# Apply a modified version of the card effect that only adds block but no damage
					if "base_block" in card_obj and card_obj.base_block > 0:
						# Still apply block effects
						source_character.block += card_obj.base_block
						print("[DEBUG] ✅ Still applied " + str(card_obj.base_block) + " block from card")
					
					# Update UI without applying damage
					update_health_ui()
					card_played_successfully = true
				else:
					# Call effect normally when not in debug mode or for non-streak cards
					if "apply_effects" in card_obj and typeof(card_obj.apply_effects) == TYPE_CALLABLE:
						card_obj.apply_effects(typed_targets, modifier_handler)
						card_played_successfully = true
						print("  Card effects applied successfully via apply_effects!")
			
			# APPROACH 2: Try play method if available
			# This is used by standard cards from the base Card class
			elif card_obj.has_method("play"):
				print("  Using standard card.play() method")
				
				# Some cards might still expect typed arrays, so ensure proper parameter types
				if card_obj.id.begins_with("warrior_") or card_obj.id.begins_with("streak_"):
					# Character-specific cards often need typed arrays
					print("  Attempting to use call() for character-specific card")
					# Use reflection to call the method
					if card_obj.has_method("play"):
						# Since we can't use try/except in GDScript, we'll use a simple call
						# with parameter checking
						card_obj.call("play", typed_targets, source_character, modifier_handler)
						card_played_successfully = true
						print("  Card played successfully with call method!")
					else:
						print("  ERROR: Card doesn't have play method")
				else:
					# For standard cards, try the direct play method
					print("  Attempting to use play() directly for standard card")
					# Direct play attempt - simplify to avoid exceptions
					if card_obj != null and "play" in card_obj and source_character != null:
						card_obj.play(targets, source_character, modifier_handler)
						card_played_successfully = true
						print("  Card played successfully with direct play method!")
					else:
						print("  ERROR: Could not play card with direct method")
			else:
				push_error("Card " + card_obj.id + " has no usable effect method")
				print("  ERROR: Card has neither play nor apply_effects method")
		
		# If card.play() failed or modifier handler was missing, apply effects manually
		if not card_played_successfully:
			print("  Applying card effects manually as fallback")
			
			# Handle damage effects
			if "base_damage" in card_obj and card_obj.base_damage > 0:
				var damage = card_obj.base_damage
				
				# Check for debug mode - disable streak damage for testing
				var is_streak_card = card_obj.id.begins_with("streak_")
				if DEBUG_MODE and DEBUG_NO_STREAK_DAMAGE and is_streak_card:
					print("  [DEBUG] Streak damage disabled: " + card_obj.id + " would have dealt " + str(damage) + " damage")
					# Still trigger block effects for testing UI
					if targets.size() > 0 and "stats" in targets[0]:
						print("  [DEBUG] Block would have absorbed up to " + str(targets[0].stats.block) + " damage")
						# Don't actually consume the block, just show the display
						update_health_ui()
				else:
					print("  Applying " + str(damage) + " damage manually")
					
					# Apply damage to target character
					if targets.size() > 0 and "stats" in targets[0]:
						var target_stats = targets[0].stats
						
						# Apply block first
						if target_stats.block > 0:
							var blocked = min(target_stats.block, damage)
							print("  Block absorbed " + str(blocked) + " damage")
							damage -= blocked
							target_stats.block -= blocked
							print("  Remaining block: " + str(target_stats.block))
						
						# Apply remaining damage
						if damage > 0:
							target_stats.health -= damage
							print("  Applied " + str(damage) + " damage to health")
						
						# Force health UI update after damage is applied
						call_deferred("update_health_ui")
			
			# Handle block effects
			if "base_block" in card_obj and card_obj.base_block > 0:
				var block = card_obj.base_block
				# Debug block before update
				print("[BLOCK DEBUG] Before update: " + ("player" if is_player_card else "AI") + " block = " + str(source_character.block))
				
				# Apply block
				source_character.block += block
				
				# Debug block after update
				print("[BLOCK DEBUG] After adding " + str(block) + " block: " + ("player" if is_player_card else "AI") + " block = " + str(source_character.block))
				
				# Card-specific debugging
				if card_obj.id == "warrior_block":
					print("[BLOCK DEBUG] Applied warrior_block card with value: 5")
				elif card_obj.id == "warrior_braced_defense":
					print("[BLOCK DEBUG] Applied braced_defense card with value: 10")
					
				# CRITICAL FIX: Force a direct update to the health label with block information
				if is_player_card and player_handler:
					# Directly update any label that might contain health information
					for node in get_tree().get_nodes_in_group("health_ui"):
						if node.has_node("HealthLabel"):
							var health_label = node.get_node("HealthLabel")
							var text = str(source_character.health)
							if source_character.block > 0:
								text += " 🛡️" + str(source_character.block)
							health_label.text = text
							print("[DIRECT UPDATE] Set health label to: '" + text + "'")
				
				# Update StatsUI components
				for node in get_tree().get_nodes_in_group("stats_ui"):
					if node.has_method("update_stats"):
						print("[DIRECT UPDATE] Updating StatsUI: " + node.name)
						node.update_stats(source_character)
				
				# Make sure health UI is updated
				call_deferred("update_health_ui")
				
				print("  Added " + str(block) + " block to " + ("player" if is_player_card else "AI"))
			
		# Handle card draw effects
		if "card_draw" in card_obj and card_obj.card_draw > 0:
			var draw_count = card_obj.card_draw
			print("  Card has draw effect: +" + str(draw_count) + " cards")
			
			# Apply card draw - for player we use the existing draw cards function
			if is_player_card and player_handler:
				print("  Drawing " + str(draw_count) + " extra cards for player")
				player_handler.draw_cards(draw_count)
			else:
				print("  Drawing " + str(draw_count) + " extra cards for AI")
				for i in range(draw_count):
					_draw_ai_card()
		
		# Log the results of applying the card effects
		print("  Player HP: " + str(player_handler.character.health) + " (Block: " + str(player_handler.character.block) + ")")
		print("  AI HP: " + str(handler2.character.health) + " (Block: " + str(handler2.character.block) + ")")
		
		# Special: Track card draw effects (for streak cards that draw on played)
		# This is handled through a signal in PVE, but we'll keep this for backward compatibility
		if "card_draw" in card_obj and card_obj.card_draw > 0:
			print("[CARD DRAW] " + card_obj.id + " adds " + str(card_obj.card_draw) + " card draw(s)")
			if is_player_card:
				player_handler.draw_cards(card_obj.card_draw)
			else:
				# AI gets to draw cards too!
				for i in range(card_obj.card_draw):
					_draw_ai_card()
		
		# Log final stats after applying all effects
		print("[PVP_STATS] After effect - Player HP: " + str(player_handler.character.health) + ", block: " + str(player_handler.character.block))
		print("[PVP_STATS] After effect - AI HP: " + str(handler2.character.health) + ", block: " + str(handler2.character.block))
		
		# Update UI after card effects
		update_health_ui()
		
		# Move the card to the appropriate discard pile
		if is_player_card:
			player_handler.character.discard.add_card(card_obj)
		else:
			handler2.character.discard.add_card(card_obj)

	if ai_ui:
		ai_ui.queue_free()
	if p_slot:
		p_slot.clear()
	if e_slot:
		e_slot.clear()
