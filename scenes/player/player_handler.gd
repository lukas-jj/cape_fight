# Player turn order:
# 1. START_OF_TURN Relics 
# 2. START_OF_TURN Statuses
# 3. Draw Hand
# 4. End Turn 
# 5. END_OF_TURN Relics 
# 6. END_OF_TURN Statuses
# 7. Discard Hand
class_name PlayerHandler
extends Node

const HAND_DRAW_INTERVAL := 0.25
const HAND_DISCARD_INTERVAL := 0.25

@export var relics: RelicHandler
@export var player: Player
@export var hand: Hand

var character: CharacterStats


func _ready() -> void:
	Events.card_played.connect(_on_card_played)


func start_battle(char_stats: CharacterStats) -> void:
#	print("[PH] start_battle called. deck:", char_stats.deck.cards.size())
	character = char_stats
	character.draw_pile = character.deck.custom_duplicate()
#	print("[PH] draw_pile after dup:", character.draw_pile.cards.size())
	character.draw_pile.shuffle()
	character.discard = CardPile.new()
	relics.relics_activated.connect(_on_relics_activated)
	player.status_handler.statuses_applied.connect(_on_statuses_applied)
	start_turn()


func start_turn() -> void:
	# TEMPORARILY DISABLED: Block reset at start of turn for testing
	# character.block = 0
	print("[BLOCK DEBUG] PlayerHandler - Block reset DISABLED, keeping block: " + str(character.block))
	
	character.reset_mana()
	relics.activate_relics_by_type(Relic.Type.START_OF_TURN)


func end_turn() -> void:
	if hand:
		hand.disable_hand()
	relics.activate_relics_by_type(Relic.Type.END_OF_TURN)


func draw_card() -> void:
	print("[PH] draw_card called")
	
	# ABSOLUTE HARD LIMIT - NEVER exceed cards_per_turn
	if hand and hand.get_child_count() >= character.cards_per_turn:
		print("[PH] HARD LIMIT REACHED - NO MORE CARDS")
		return
		
	reshuffle_deck_from_discard()
	var card := character.draw_pile.draw_card()
	if hand:
		hand.add_card(card)
		print("[PH] hand child count:", hand.get_child_count(), "/", character.cards_per_turn)
		
	# If no hand assigned (e.g., AI disabled), skip UI add but keep card removed from draw pile
	reshuffle_deck_from_discard()
	

# Add a single card directly to the hand - useful for debugging and manual card creation
func add_card_to_hand(card: Card) -> void:
	if not hand:
		print("[PH] ERROR: Cannot add card to hand - no hand reference")
		return
		
	if not card:
		print("[PH] ERROR: Cannot add null card to hand")
		return
		
	if hand.get_child_count() >= character.cards_per_turn:
		print("[PH] Warning: Cannot add more cards - hand full")
		return
		
	# This is the same logic as in hand.add_card but with additional debug info
	print("[PH] Manually adding card " + card.id + " to hand")
	hand.add_card(card)
	print("[PH] Card added with cost: " + str(card.cost) + ", hand now has: " + str(hand.get_child_count()) + " cards")


func draw_cards(amount: int, is_start_of_turn_draw: bool = false) -> void:
	# CRITICAL FIX - enforce cards_per_turn limit
	if is_start_of_turn_draw and character and character.cards_per_turn > 0:
		print("[PH] ENFORCING limit: ", character.cards_per_turn, " cards maximum")
		amount = min(amount, character.cards_per_turn)
		
	# Clear existing hand
	if hand and is_start_of_turn_draw:
		print("[PH] Clearing existing hand")
		for child in hand.get_children():
			child.queue_free()
	
	print("[PH] Drawing ", amount, " cards") 
	var tween := create_tween()
	for i in range(amount):
		tween.tween_callback(draw_card)
		tween.tween_interval(HAND_DRAW_INTERVAL)
	
	tween.finished.connect(
		func(): 
			if hand:
				hand.enable_hand()
				print("[PH] draw_cards finished – hand size:", hand.get_child_count())
			if is_start_of_turn_draw:
				Events.player_hand_drawn.emit()
	)


func discard_cards() -> void:
	if not hand or hand.get_child_count() == 0:
		Events.player_hand_discarded.emit()
		return

	var tween := create_tween()
	for card_ui: CardUI in hand.get_children():
		tween.tween_callback(character.discard.add_card.bind(card_ui.card))
		tween.tween_callback(hand.discard_card.bind(card_ui))
		tween.tween_interval(HAND_DISCARD_INTERVAL)
	
	tween.finished.connect(func(): Events.player_hand_discarded.emit())


func reshuffle_deck_from_discard() -> void:
	# Check that all required objects exist
	if not character or not character.draw_pile or not character.discard:
		print("[ERROR] Cannot reshuffle - missing character, draw_pile or discard pile")
		return
	
	# Check if draw pile already has cards
	if not character.draw_pile.cards.is_empty():
		return

	# Move cards from discard to draw pile
	while not character.discard.cards.is_empty():
		character.draw_pile.add_card(character.discard.draw_card())

	# Shuffle the new draw pile
	character.draw_pile.shuffle()


func _on_card_played(card: Card) -> void:
	if card.exhausts or card.type == Card.Type.POWER:
		return
	
	character.discard.add_card(card)


func _on_statuses_applied(type: Status.Type) -> void:
	# Defer actions to next idle frame to prevent deep recursive signal chains
	match type:
		Status.Type.START_OF_TURN:
			call_deferred("draw_cards", character.cards_per_turn, true)
		Status.Type.END_OF_TURN:
			call_deferred("discard_cçards")


func _on_relics_activated(type: Relic.Type) -> void:
	match type:
		Relic.Type.START_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.START_OF_TURN)
		Relic.Type.END_OF_TURN:
			player.status_handler.apply_statuses_by_type(Status.Type.END_OF_TURN)
