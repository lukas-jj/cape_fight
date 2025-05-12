class_name BattleUI
extends CanvasLayer

@export var char_stats: CharacterStats : set = _set_char_stats

@onready var hand: Hand                     = $Hand
@onready var mana_ui: ManaUI                = $ManaUI
@onready var end_turn_button: Button        = $EndTurnButton
# after:
@onready var draw_pile_button: CardPileOpener    = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = $DiscardPileButton
@onready var draw_pile_view: CardPileView        = %DrawPileView
@onready var discard_pile_view: CardPileView     = %DiscardPileView

var player_slots: Array[CardSlot] = []
var enemy_slots : Array[CardSlot] = []

const SLOT_OFFSET_X := [-220, 0, 220]
const SLOT_Y := -180
const ENEMY_SLOT_Y := 80

func _ready() -> void:
	# — collect any CardSlot children as your player slots
	for child in get_children():
		if child is CardSlot:
			player_slots.append(child)

	# — spawn missing ones if <3
	var needed = 3 - player_slots.size()
	if needed > 0:
		var slot_scene = preload("res://scenes/ui/card_slot.tscn")
		var vsz = get_viewport().get_visible_rect().size
		for i in range(needed):
			var s = slot_scene.instantiate() as CardSlot
			add_child(s)
			player_slots.append(s)
			s.global_position = Vector2(vsz.x/2 + SLOT_OFFSET_X[i], vsz.y + SLOT_Y)

	# — collect enemy slots by group or under EnemySlots node
	for n in get_tree().get_nodes_in_group("enemy_card_slots"):
		if n is CardSlot:
			enemy_slots.append(n)
	var cont = get_node_or_null("EnemySlots")
	if cont:
		for c in cont.get_children():
			if c is CardSlot and not enemy_slots.has(c):
				enemy_slots.append(c)

	# — sort left→right
	player_slots.sort_custom(Callable(self, "_compare_x"))
	enemy_slots.sort_custom(Callable(self, "_compare_x"))

	print("[BattleUI] P slots:", player_slots.size(), " E slots:", enemy_slots.size())

	# — wire up events (draw/discard UI hookup happens later)
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)


func get_player_slots() -> Array[CardSlot]:
	return player_slots

func get_enemy_slots() -> Array[CardSlot]:
	return enemy_slots


func _set_char_stats(v: CharacterStats) -> void:
	char_stats = v
	mana_ui.char_stats = v
	hand.char_stats    = v


func initialize_card_pile_ui() -> void:
	# Now that char_stats is non-null, wire up the UI
	draw_pile_button.card_pile    = char_stats.draw_pile
	draw_pile_view.card_pile      = char_stats.draw_pile
	discard_pile_button.card_pile = char_stats.discard
	discard_pile_view.card_pile   = char_stats.discard


func _compare_x(a: CardSlot, b: CardSlot) -> bool:
	return a.global_position.x < b.global_position.x


func _on_player_hand_drawn() -> void:
	# just bubble up; we disable until PvpBattle decides
	end_turn_button.disabled = true


func _on_end_turn_button_pressed() -> void:
	# bubble up to PvpBattle
	Events.player_turn_ended.emit()
