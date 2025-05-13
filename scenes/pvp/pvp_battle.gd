class_name PvpBattle
extends Node2D

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

	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	Events.player_turn_ended.connect(_on_end_turn_pressed)

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
	for s in battle_ui.player_slots:
		s.card_changed.connect(_on_slot_card_changed)

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

	var ids = []
	for c in ai_hand:
		if c:
			ids.append(c.id)
		else:
			print("[WARNING] Found null card in AI hand")
	print("[AI HAND] Count:", ids.size(), "→", ids)

func _on_player_hand_drawn() -> void:
	var ids = []
	for ui in battle_ui.hand.get_children():
		if ui and ui.card:
			ids.append(ui.card.id)
		else:
			print("[WARNING] Found card UI with null card")
	print("[PLAYER HAND] Count:", ids.size(), "→", ids)
	
	# Verify cards match the expected character
	var character_name = "warrior"
	if player and player.stats:
		if player.stats.resource_path and player.stats.resource_path.get_file():
			var filename = player.stats.resource_path.get_file()
			if "." in filename:
				character_name = filename.split(".")[0]
	
	print("[VERIFY HAND] Expected character: ", character_name)
	for card_id in ids:
		if not card_id.begins_with(character_name):
			print("[VERIFY ERROR] Card ", card_id, " doesn't match character ", character_name, "!")
		else:
			print("[VERIFY OK] Card ", card_id, " matches character")

func _on_slot_card_changed(card_ui: CardUI) -> void:
	var filled = 0
	for s in battle_ui.player_slots:
		if not s.is_empty():
			filled += 1
	end_turn_btn.disabled = (filled < 3)

func _on_end_turn_pressed() -> void:
	# Immediately disable button to prevent multiple calls
	end_turn_btn.disabled = true
	
	# Explicitly clear hand UI
	if battle_ui and battle_ui.hand:
		for child in battle_ui.hand.get_children():
			child.queue_free()
	
	# Log deck states before proceeding
	print("[DEBUG] End turn pressed with state:")
	print("  Player deck: ", player.stats.resource_path, ", cards left: ", player.stats.draw_pile.cards.size())
	print("  AI deck: ", player2.stats.resource_path, ", cards left: ", player2.stats.draw_pile.cards.size())
	print("[DEBUG] Calling _ai_pick_three()")
	var picks = await _ai_pick_three()
	print("[DEBUG] After _ai_pick_three() returned picks size=", picks.size())
	for i in range(3):
		var ai_card : Card = null
		if i < picks.size():
			ai_card = picks[i]
		_resolve_slot(i, ai_card)

	for s in battle_ui.player_slots + battle_ui.enemy_slots:
		s.clear()

	for card_ui in battle_ui.hand.get_children():
		if card_ui.card:
			player_handler.character.discard.add_card(card_ui.card)
		card_ui.queue_free()

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
	
	# Apply the copies
	player_handler.character = player_stats_copy
	handler2.character = ai_stats_copy
	
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
		print("[PLAYER DECK] Using initial warrior deck")
		player_deck_cards = player.stats.starting_deck.duplicate_cards()
		
	# Same for AI
	if handler2.character.discard and not handler2.character.discard.empty():
		print("[AI RESHUFFLE] Using", handler2.character.discard.size(), "cards from discard")
		while not handler2.character.discard.empty():
			ai_deck_cards.append(handler2.character.discard.draw_card())
	else:
		# If no discard cards, use the initial deck as fallback
		print("[AI DECK] Using initial speedster deck")
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
	print("[DECK FILL] Adding", player_deck_cards.size(), "warrior cards to player draw pile")
	for card in player_deck_cards:
		player_handler.character.draw_pile.add_card(card)
	player_handler.character.draw_pile.shuffle()
	
	# Add cards to AI draw pile
	print("[DECK FILL] Adding", ai_deck_cards.size(), "speedster cards to AI draw pile")
	for card in ai_deck_cards:
		handler2.character.draw_pile.add_card(card)
	handler2.character.draw_pile.shuffle()
	
	# Now proceed with turn change
	print("[DEBUG] Player handler using stats:", player_handler.character.resource_path)
	
	# Brute force fix for duplicate draw calls
	# 1. Set card limits
	player_handler.character.cards_per_turn = 4  # Force this to be 4
	handler2.character.cards_per_turn = 4  # Force this to be 4
	
	# 2. AGGRESSIVE clearing - destroy everything in the hand
	if battle_ui and battle_ui.hand:
		print("[FORCE CLEAR] Wiping out entire hand UI")
		for i in range(10):  # Extra loops to ensure everything is gone
			for child in battle_ui.hand.get_children():
				child.queue_free()
			await get_tree().process_frame
		
	# 3. Handle turn transition WITHOUT using the normal functions
	# We'll handle card drawing ourselves to avoid duplicate calls
	print("[CUSTOM TURN] Skipping normal start_turn and doing direct draw")
	
	# 4. Reset some basic state
	player_handler.character.block = 0
	player_handler.character.reset_mana()
	
	# 5. Draw exactly 4 cards ourselves
	print("[DIRECT DRAW] Drawing exactly 4 cards for player")
	for i in range(4):
		if player_handler.character.draw_pile.empty():
			player_handler.reshuffle_deck_from_discard()
		var card = player_handler.character.draw_pile.draw_card()
		if player_handler.hand and card:
			player_handler.hand.add_card(card)
			
	# Enable the hand now that cards are drawn
	if player_handler.hand:
		player_handler.hand.enable_hand()
	
	# Emit the hand drawn event
	print("[MANUAL] Emitting player_hand_drawn")
	Events.player_hand_drawn.emit()
	
	# Draw AI hand
	_draw_ai_hand()

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

			ui.char_stats = player2.stats
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
	# Add debug output
	print("\n[RESOLVE SLOT] ====== STARTING RESOLUTION FOR SLOT ", idx, " ======")
	
	var p_slot = battle_ui.player_slots[idx]
	var e_slot = battle_ui.enemy_slots[idx]
	var p_ui   = p_slot.card_ui
	var ai_ui  = e_slot.card_ui
	# Backup: the picked card object in case UI assignment failed
	var ai_card_obj : Card = ai_card
	
	print("[RESOLVE] Player card: ", p_ui.card.id if p_ui and p_ui.card else "None")
	print("[RESOLVE] AI card: ", ai_ui.card.id if ai_ui and ai_ui.card else (ai_card.id if ai_card else "None"))

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

	print("[RESOLVE] Slot", idx, ": P=", p_id, "(Speed:", rp, "), AI=", ai_id, "(Speed:", re, ")")

	var order = []
	if p_ui and p_ui.card and ai_ui and ai_ui.card:
		if rp > re:
			order.append(p_ui)
			order.append(ai_ui)
			print("[ORDER] Player card is faster")
		elif re > rp:
			order.append(ai_ui)
			order.append(p_ui)
			print("[ORDER] AI card is faster")
		else:
			if _rng.randi_range(0, 1) == 0:
				order.append(p_ui)
				order.append(ai_ui)
				print("[ORDER] Same speed, randomly chose Player first")
			else:
				order.append(ai_ui)
				order.append(p_ui)
				print("[ORDER] Same speed, randomly chose AI first")
	elif p_ui and p_ui.card:
		order.append(p_ui)
		print("[ORDER] Only Player card present")
	elif ai_card_obj:
		# create temporary order wrapper by using null UI but card object
		order.append(ai_card_obj)
		print("[ORDER] Only AI backup card present")
	else:
		print("[ORDER] No valid cards to resolve at Slot", idx)

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
			owner_stats = player.stats
			owner_modifiers = player.modifier_handler
		else:
			owner_stats = player2.stats
			owner_modifiers = player2.modifier_handler

		var target_nodes : Array[Node] = []

		# Print out detailed debug info
		var attributes = []
		if "damage_amount" in card_obj:
			attributes.append("damage=" + str(card_obj.damage_amount))
		if "block_amount" in card_obj:
			attributes.append("block=" + str(card_obj.block_amount))
		if attributes.is_empty():
			attributes = ["<no damage/block properties>"]
		
		print("[PVP_CARD] Playing card: ", card_obj.id, ", owner: ", "Player" if is_player_card else "AI", 
			", target: ", Card.Target.keys()[card_obj.target], ", cost: ", card_obj.cost, ", ", ", ".join(attributes))
		
		# First set the targeting for the current card
		if card_obj.target == Card.Target.SELF:
			# Self-targeting (e.g. Block) should affect the card owner
			if is_player_card:
				target_nodes = [player]
				print("[PVP_CARD] Player self-targeting with ", card_obj.id, " -> target=player")
			else:
				target_nodes = [player2]
				print("[PVP_CARD] AI self-targeting with ", card_obj.id, " -> target=AI")
		else:
			# Offensive / enemy-targeting cards
			if is_player_card:
				target_nodes = [player2]
				print("[PVP_CARD] Player targeting AI with ", card_obj.id)
			else:
				target_nodes = [player]
				print("[PVP_CARD] AI targeting Player with ", card_obj.id)

		# For debugging - directly access both players' stats before effect
		print("[PVP_STATS] Before effect - Player HP: ", player.stats.health, ", block: ", player.stats.block)
		print("[PVP_STATS] Before effect - AI HP: ", player2.stats.health, ", block: ", player2.stats.block)
		
		# Execute the card
		Events.card_played.emit(card_obj)
		owner_stats.mana -= card_obj.cost
		card_obj.apply_effects(target_nodes, owner_modifiers)
		
		# MEGA DAMAGE FIX: Apply hardcoded damage values for ALL cards
		if is_player_card:
			print("[PVP_FIX] Warrior card: ", card_obj.id)
			
			# Handle warrior damage by card ID
			var damage = 0
			if card_obj.id == "warrior_slash":
				damage = 4
			elif card_obj.id == "warrior_big_slam":
				damage = 8
			elif card_obj.id == "warrior_block":
				# Block card, no damage
				print("[BLOCK] Adding 5 block to player")
				player.stats.block += 5
			elif card_obj.id == "warrior_braced_defense":
				# Defense card, no damage
				print("[BLOCK] Adding 10 block to player")
				player.stats.block += 10
			
			# Apply damage if this is an attack
			if damage > 0:
				# ALWAYS apply damage directly to health, ignoring other effects
				player2.stats.health -= damage
				print("[BRUTE FORCE] Applied ", damage, " GUARANTEED damage to AI")
				print("[HEALTH] AI health now: ", player2.stats.health)
		else:
			print("[PVP_FIX] Speedster card: ", card_obj.id)
			
			# Handle speedster damage by card ID
			var damage = 0
			if card_obj.id == "streak_quick_strike":
				damage = 5
			elif card_obj.id == "streak_chain_dash":
				damage = 6
			elif card_obj.id == "streak_phase_shift":
				# Phase shift gives block to AI
				print("[BLOCK] Adding 5 block to AI")
				player2.stats.block += 5
					
			# Apply damage if this is an attack
			if damage > 0:
				# ALWAYS apply damage directly to health, ignoring other effects
				player.stats.health -= damage
				print("[BRUTE FORCE] Applied ", damage, " GUARANTEED damage to Player")
				print("[HEALTH] Player health now: ", player.stats.health)
				
			# After effect stats
			print("[PVP_STATS] After effect - Player HP: ", player.stats.health, ", block: ", player.stats.block)
			print("[PVP_STATS] After effect - AI HP: ", player2.stats.health, ", block: ", player2.stats.block)
			
			# Print stats after effect
			if target_nodes.size() > 0 and target_nodes[0] is Player:
				var target_player = target_nodes[0] as Player
				print("[PVP_STATS] After effect - target HP: ", target_player.stats.health, ", block: ", target_player.stats.block)
		# REMOVED - merged into unified card execution flow above

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
