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

	# NOW set BattleUI.char_stats and wire up piles
	battle_ui.char_stats = player.stats
	battle_ui.initialize_card_pile_ui()

	_start_battle()

	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	Events.player_turn_ended.connect(_on_end_turn_pressed)


func _load_stats() -> void:
	if PvpData.player_stats:
		player.stats  = PvpData.player_stats.create_instance()
	else:
		player.stats  = CharacterStats.new()

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
	# add all slots to the “card_slots” group for drop detection
	for s in battle_ui.player_slots + battle_ui.enemy_slots:
		s.add_to_group("card_slots")

	# disable end‐turn until 3 placed
	end_turn_btn.disabled = true
	for s in battle_ui.player_slots:
		s.card_changed.connect(_on_slot_card_changed)


func _start_battle() -> void:
	# link your handlers
	player_handler.hand = battle_ui.hand
	handler2.hand       = null

	player_handler.start_battle(player.stats)
	handler2.start_battle(player2.stats)

	# both draw their opening hand
	#player_handler.start_turn()  # this will emit player_hand_drawn once done
	_draw_ai_hand()              # log AI hand now


func _draw_ai_hand() -> void:
	ai_hand.clear()
	for i in range(player2.stats.cards_per_turn):
		if player2.stats.draw_pile.empty():
			break
		ai_hand.append(player2.stats.draw_pile.draw_card())

	var ids = []
	for c in ai_hand:
		ids.append(c.id)
	print("[AI HAND] Count:", ids.size(), "→", ids)


func _on_player_hand_drawn() -> void:
	var ids = []
	for ui in battle_ui.hand.get_children():
		ids.append(ui.card.id)
	print("[PLAYER HAND] Count:", ids.size(), "→", ids)


func _on_slot_card_changed(card_ui: CardUI) -> void:
	var filled = 0
	for s in battle_ui.player_slots:
		if not s.is_empty():
			filled += 1
	end_turn_btn.disabled = (filled < 3)


func _on_end_turn_pressed() -> void:
	# collect AI picks & populate enemy slots
	var picks = _ai_pick_three()

	for i in range(3):
		var ai_card : Card = null
		if i < picks.size():
			ai_card = picks[i]
		_resolve_slot(i, ai_card)

	# clear all slots for next turn
	for s in battle_ui.player_slots + battle_ui.enemy_slots:
		s.clear()

	# finish and start next turn
	player_handler.end_turn()
	player_handler.start_turn()
	_draw_ai_hand()


func _ai_pick_three() -> Array[Card]:
	var picks = []

	# use AI’s hand first
	while ai_hand.size() > 0 and picks.size() < 3:
		picks.append(ai_hand.pop_back())

	# top up from draw pile
	while picks.size() < 3 and not player2.stats.draw_pile.empty():
		picks.append(player2.stats.draw_pile.draw_card())

	# manual Fisher–Yates shuffle
	for i in range(picks.size()):
		var j = _rng.randi_range(i, picks.size() - 1)
		var tmp = picks[i]
		picks[i] = picks[j]
		picks[j] = tmp

	# show in enemy UI slots
	var ids = []
	for idx in range(battle_ui.enemy_slots.size()):
		var slot = battle_ui.enemy_slots[idx]
		slot.clear()
		if idx < picks.size():
			var ui = CARD_UI_SCENE.instantiate() as CardUI
			ui.card       = picks[idx]
			ui.char_stats = player2.stats
			ui.disabled   = true
			slot.accept_card(ui)
			ids.append(picks[idx].id)
	print("[AI PICKS] Count:", ids.size(), "→", ids)

	return picks


func _resolve_slot(idx: int, ai_card: Card) -> void:
	var p_slot = battle_ui.player_slots[idx]
	var p_ui   = p_slot.card_ui

	# build a throwaway AI UI for resolution
	var ai_ui: CardUI = null
	if ai_card != null:
		ai_ui = CARD_UI_SCENE.instantiate() as CardUI
		ai_ui.card       = ai_card
		ai_ui.char_stats = player2.stats
		ai_ui.disabled   = true

	# decide order
	var order = []
	if p_ui and ai_ui:
		var rp = _speed_rank(p_ui.card.speed)
		var re = _speed_rank(ai_ui.card.speed)
		if rp >= re:
			order = [p_ui, ai_ui]
		else:
			order = [ai_ui, p_ui]
	elif p_ui:
		order = [p_ui]
	elif ai_ui:
		order = [ai_ui]

	# play them
	for ui in order:
		if ui == p_ui:
			ui.card.play([player2], player.stats, player.modifier_handler)
			player_handler.character.discard.add_card(ui.card)
		else:
			ui.card.play([player], player2.stats, player2.modifier_handler)
			handler2.character.discard.add_card(ui.card)

	p_slot.clear()
	if ai_ui:
		ai_ui.free()
