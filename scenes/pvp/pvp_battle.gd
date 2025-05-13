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
	# Immediately disable button to prevent multiple calls
	end_turn_btn.disabled = true
	print("[DEBUG] End turn pressed, calling _ai_pick_three()")
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

	player_handler.end_turn()
	player_handler.start_turn()
	_draw_ai_hand()

# ============================
# MAIN AI CARD SLOT LOGIC ZONE
# ============================
func _ai_pick_three() -> Array[Card]:
	print("[DEBUG] _ai_pick_three(): ai_hand.size()=", ai_hand.size(), ", starting draw.")
	var picks: Array[Card] = []
	while ai_hand.size() > 0 and picks.size() < 3:
		picks.append(ai_hand.pop_back())
	print("[DEBUG] After ai_hand pop: picks.size()=", picks.size())
	while picks.size() < 3 and not player2.stats.draw_pile.empty():
		picks.append(player2.stats.draw_pile.draw_card())
	# Shuffle picks
	var debug_ids = []
	for p in picks:
		debug_ids.append(p.id)
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
	var p_slot = battle_ui.player_slots[idx]
	var e_slot = battle_ui.enemy_slots[idx]
	var p_ui   = p_slot.card_ui
	var ai_ui  = e_slot.card_ui
	# Backup: the picked card object in case UI assignment failed
	var ai_card_obj : Card = ai_card

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
			# Fix: player2 is a Player node, so access modifier_handler directly
			owner_modifiers = player2.modifier_handler

		var target_nodes : Array[Node] = []

		# Determine correct targets based on card type
		if card_obj.target == Card.Target.SELF:
			# Self-targeting (e.g. Block) should affect the card owner
			if is_player_card:
				target_nodes = [player]
			else:
				target_nodes = [player2]

			# Manually execute the card to avoid _get_targets() returning the wrong entity
			Events.card_played.emit(card_obj)
			owner_stats.mana -= card_obj.cost
			card_obj.apply_effects(target_nodes, owner_modifiers)
		else:
			# Offensive / enemy-targeting cards
			if is_player_card:
				target_nodes = [player2]
			else:
				target_nodes = [player]
			card_obj.play(target_nodes, owner_stats, owner_modifiers)

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
