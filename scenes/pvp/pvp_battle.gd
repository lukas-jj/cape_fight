class_name PvpBattle
extends Node2D

const PvpData := preload("res://pvp_data.gd")
@export var battle_stats: BattleStats
@export var char_stats: CharacterStats
#@export var music: AudioStream
@export var relics: RelicHandler

@onready var battle_ui: BattleUI = $BattleUI
@onready var player_handler: PlayerHandler = $PlayerHandler
@onready var player: Player = $Player
@onready var player2: Player = $Player2
@onready var handler2: PlayerHandler = $PlayerHandler2

# No separate UI hand for player2 in PvP; AI logic uses handler2 only

# --- Turn tracking flags ---
# True when we are waiting for the AI turn to start after the player's discard.
var _awaiting_ai_turn: bool = false

func _ready() -> void:
	Events.player_turn_ended.connect(_on_player_turn_ended)
	Events.player_died.connect(_on_player_died)

	# Apply chosen stats
	if PvpData.player_stats:
		player.stats = PvpData.player_stats.create_instance()
		# Force player to draw only 4 cards per turn for PvP slots
		player.stats.cards_per_turn = 4
	if PvpData.ai_stats:
		player2.stats = PvpData.ai_stats.create_instance()
	print("[PvP] Stats applied. Player:", player.stats.character_name, "Deck size:", player.stats.deck.cards.size())
	print("[PvP] Stats applied. AI:", player2.stats.character_name, "Deck size:", player2.stats.deck.cards.size())

	# Ensure we have relic handlers
	if relics == null:
		var rh_scene := preload("res://scenes/relic_handler/relic_handler.tscn")
		relics = rh_scene.instantiate() as RelicHandler
		add_child(relics)
		print("[PvP] Player relic handler instantiated. Children:", relics.get_child_count())
	# Create a separate relic handler for AI (needed for signal safety)
	var rh_scene2 := preload("res://scenes/relic_handler/relic_handler.tscn")
	var ai_relics := rh_scene2.instantiate() as RelicHandler
	add_child(ai_relics)
	print("[PvP] AI relic handler instantiated. Children:", ai_relics.get_child_count())

	player_handler.relics = relics
	handler2.relics = ai_relics

	# Wait until player hand is discarded before AI turn
	if not Events.player_hand_discarded.is_connected(_on_player_hand_discarded):
		Events.player_hand_discarded.connect(_on_player_hand_discarded)
	# Track when the player draws a new hand – that means next discard should trigger AI turn
	if not Events.player_hand_drawn.is_connected(_on_player_hand_drawn):
		Events.player_hand_drawn.connect(_on_player_hand_drawn)
	# Initially player will draw at start of combat, so set awaiting flag to false until first draw occurs
	_awaiting_ai_turn = false

	# Initialize UI with player stats and card piles
	battle_ui.char_stats = player.stats
	battle_ui.hand.char_stats = player.stats
	battle_ui.hand.player = player

	# Ensure handlers know correct hand nodes
	player_handler.hand = battle_ui.hand

	# Ensure discard connections like PvE
	if not Events.card_played.is_connected(player_handler._on_card_played):
		Events.card_played.connect(player_handler._on_card_played)
	if not Events.card_played.is_connected(handler2._on_card_played):
		Events.card_played.connect(handler2._on_card_played)

	print("[PvP] Deck size:", player.stats.deck.cards.size())
	print("[PvP] Starting draw pile size:", player.stats.draw_pile.cards.size())

	# Hook into relic-driven flow like regular battle scene
	relics.relics_activated.connect(_on_relics_activated)
	relics.activate_relics_by_type(Relic.Type.START_OF_COMBAT)

	# Connect slot change signals to track when 3 chosen
	for s in battle_ui.slots:
		if not s.card_changed.is_connected(_on_slot_card_changed):
			s.card_changed.connect(_on_slot_card_changed)
	print("[PvP] battle_ui.slots size:", battle_ui.slots.size())
	_debug_print_slots("[PvP] After slot setup -> ")

	# Remove any template enemies from duplicated scene
	if has_node("EnemyHandler"):
		$EnemyHandler.queue_free()

	# No need to track scene_changed in PvP battle, Godot 4 may lack this signal on SceneTree


func start_battle() -> void:
	pass


func _on_enemies_child_order_changed() -> void:
	pass


func _on_player_turn_ended() -> void:
	print("[PvP] Player turn ended – waiting for discard before AI")
	# Discard will trigger Events.player_hand_discarded; mark that AI turn should follow
	_awaiting_ai_turn = true
	if battle_ui.hand.get_child_count() == 0:
		# Nothing to discard, continue immediately
		_on_player_hand_discarded()


func _on_player_hand_discarded() -> void:
	print("[PvP] Hand discarded – AI turn now")
	# Only trigger AI turn if we're expecting it (i.e., discard from the human player)
	if not _awaiting_ai_turn:
		print("[PvP] Discard from AI – ignoring.")
		return
	_awaiting_ai_turn = false
	_ai_take_turn()
	player_handler.start_turn()


func _ai_take_turn() -> void:
	handler2.end_turn()
	print("[PvP] AI turn finished.")


func _after_enemy_end_statuses(_type):
	pass


func _on_player_died() -> void:
	Events.battle_over_screen_requested.emit("Game Over!", BattleOverPanel.Type.LOSE)
	SaveGame.delete_data()


func _on_relics_activated(type: Relic.Type) -> void:
	match type:
		Relic.Type.START_OF_COMBAT:
			player_handler.start_battle(player.stats)
			handler2.start_battle(player2.stats)
			battle_ui.initialize_card_pile_ui()
		Relic.Type.END_OF_COMBAT:
			if char_stats:
				print(char_stats.resource_name)
			Events.battle_over_screen_requested.emit("Victory!", BattleOverPanel.Type.WIN)


# Helper – called when any slot changes. If all 3 slots filled, play them automatically.
func _on_slot_card_changed(_card_ui: CardUI) -> void:
	print("[PvP] slot_changed signal received")
	_debug_print_slots("[PvP] Current -> ")
	if _all_slots_filled():
		print("[PvP] _all_slots_filled() == true")
		_play_player_slots()
	else:
		print("[PvP] slots not full yet")


func _all_slots_filled() -> bool:
	for s: CardSlot in battle_ui.slots:
		if s.is_empty():
			return false
	return true


func _play_player_slots() -> void:
	print("[PvP] All slots filled – executing player turn")
	_debug_print_slots("[PvP] Playing -> ")
	for s: CardSlot in battle_ui.slots:
		var c_ui: CardUI = s.card_ui
		if c_ui and is_instance_valid(c_ui):
			print("[PvP] playing card:", c_ui.card.resource_name)
			c_ui.card.play([player2], player.stats, player.modifier_handler)
			# move card to discard pile resource (already added above)
			player_handler.character.discard.add_card(c_ui.card)
			# Free the CardUI so it disappears and won't be counted in hand
			c_ui.queue_free()
			s.card_ui = null
	
	# Clear slots visuals
	for s in battle_ui.slots:
		s.clear()
	
	_debug_print_slots("[PvP] After play -> ")
	# End player turn like clicking button
	player_handler.end_turn()
	print("[PvP] Player turn ended via auto-play, Events.player_turn_ended.emit()")
	Events.player_turn_ended.emit()
	# Disable End Turn button until next draw
	battle_ui.end_turn_button.disabled = true


# === DEBUG HELPERS ===
func _debug_print_slots(prefix: String = "") -> void:
	var states := []
	for i in range(battle_ui.slots.size()):
		var s: CardSlot = battle_ui.slots[i]
		var card_name := "EMPTY"
		if not s.is_empty():
			card_name = s._debug_card_name(s.card_ui)
		states.append(str(i, ":", card_name))
	var joined := ", ".join(PackedStringArray(states))
	print(prefix, "SlotStates[", joined, "]")

# Reset flag when player draws new hand (start of player turn)
func _on_player_hand_drawn() -> void:
	_awaiting_ai_turn = true
	print("[PvP] Player hand drawn – awaiting_ai_turn set to", _awaiting_ai_turn)
