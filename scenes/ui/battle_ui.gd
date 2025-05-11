class_name BattleUI
extends CanvasLayer

@export var char_stats: CharacterStats : set = _set_char_stats

@onready var hand: Hand = $Hand
@onready var mana_ui: ManaUI = $ManaUI
@onready var end_turn_button: Button = %EndTurnButton
@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton
@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView
# PvP card slots
var slot_container: HBoxContainer = null
var slots: Array[CardSlot] = []

# Fallback manual slot placement offsets (relative to screen centre)
const SLOT_OFFSET_X := [-220, 0, 220]
const SLOT_Y := -180  # distance from bottom of viewport

func _ready() -> void:
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	draw_pile_button.pressed.connect(draw_pile_view.show_current_view.bind("Draw Pile", true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_view.bind("Discard Pile"))
	
	# Remove legacy SlotContainer node if still present
	slot_container = get_node_or_null("SlotContainer")
	if slot_container:
		print("[BattleUI] Removing legacy SlotContainer node")
		slot_container.queue_free()
		slot_container = null

	# Collect any CardSlot children already placed in the scene (so designers can position them in-editor)
	for child in get_children():
		if child is CardSlot:
			slots.append(child)

	# If fewer than 3 pre-placed, spawn the missing ones programmatically
	var needed := 3 - slots.size()
	if needed > 0:
		print("[BattleUI] Spawning", needed, "CardSlots to reach 3 total")
		var slot_scene := preload("res://scenes/ui/card_slot.tscn")
		var view_size := get_viewport().get_visible_rect().size
		for i in range(needed):
			var s := slot_scene.instantiate() as CardSlot
			add_child(s)
			slots.append(s)
			var index := slots.size() - 1  # 0-based overall index after append
			# Position newly spawned ones with fallback offsets
			s.global_position = Vector2(view_size.x / 2 + SLOT_OFFSET_X[index], view_size.y + SLOT_Y)

	print("[BattleUI] slots total:", slots.size())
	for i in range(slots.size()):
		var s := slots[i]
		print("[BattleUI] Slot", i, "global pos:", s.global_position, " size:", s.size)

func initialize_card_pile_ui() -> void:
	draw_pile_button.card_pile = char_stats.draw_pile
	draw_pile_view.card_pile = char_stats.draw_pile
	discard_pile_button.card_pile = char_stats.discard
	discard_pile_view.card_pile = char_stats.discard

func _set_char_stats(value: CharacterStats) -> void:
	char_stats = value
	mana_ui.char_stats = char_stats
	hand.char_stats = char_stats

func _on_player_hand_drawn() -> void:
	end_turn_button.disabled = false

func _on_end_turn_button_pressed() -> void:
	end_turn_button.disabled = true
	Events.player_turn_ended.emit()
