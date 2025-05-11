class_name CardUI
extends Control

signal reparent_requested(which_card_ui: CardUI)

const BASE_STYLEBOX := preload("res://scenes/card_ui/card_base_stylebox.tres")
const DRAG_STYLEBOX := preload("res://scenes/card_ui/card_drag_stylebox.tres")
const HOVER_STYLEBOX := preload("res://scenes/card_ui/card_hover_stylebox.tres")

@export var player_modifiers: ModifierHandler
@export var card: Card : set = _set_card
@export var char_stats: CharacterStats : set = _set_char_stats

@onready var card_visuals: CardVisuals = $CardVisuals
@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine
@onready var targets: Array[Node] = []

var original_index := 0
var parent: Control
var tween: Tween
var playable := true : set = _set_playable
var disabled := true


func _ready() -> void:
	Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_ended.connect(_on_card_drag_or_aim_ended)
	Events.card_aim_ended.connect(_on_card_drag_or_aim_ended)
	card_state_machine.init(self)


func _input(event: InputEvent) -> void:
	card_state_machine.on_input(event)


func animate_to_position(new_position: Vector2, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", new_position, duration)


func play() -> void:
	if not card:
		return
	
	card.play(targets, char_stats, player_modifiers)
	queue_free()


func get_active_enemy_modifiers() -> ModifierHandler:
	if targets.is_empty() or targets.size() > 1 or not targets[0] is Enemy:
		return null
	
	return targets[0].modifier_handler


func is_hovered() -> bool:
	var rect := Rect2(Vector2.ZERO, self.size)
	return rect.has_point(get_local_mouse_position())


func request_tooltip() -> void:
	var enemy_modifiers := get_active_enemy_modifiers()
	var updated_tooltip := card.get_updated_tooltip(player_modifiers, enemy_modifiers)
	Events.card_tooltip_requested.emit(card.icon, updated_tooltip)


func _on_gui_input(event: InputEvent) -> void:
	card_state_machine.on_gui_input(event)


func _on_mouse_entered() -> void:
	card_state_machine.on_mouse_entered()


func _on_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()


func _set_card(value: Card) -> void:
	if not is_node_ready():
		await ready

	card = value
	card_visuals.card = card


func _set_playable(value: bool) -> void:
	playable = value
	if not playable:
		card_visuals.cost.add_theme_color_override("font_color", Color.RED)
		card_visuals.icon.modulate = Color(1, 1, 1, 0.5)
	else:
		card_visuals.cost.remove_theme_color_override("font_color")
		card_visuals.icon.modulate = Color(1, 1, 1, 1)


func _set_char_stats(value: CharacterStats) -> void:
	if value == null:
		return
	char_stats = value
	if char_stats.stats_changed and not char_stats.stats_changed.is_connected(_on_char_stats_changed):
		char_stats.stats_changed.connect(_on_char_stats_changed)
	_on_char_stats_changed()


func _on_drop_point_detector_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)


func _on_drop_point_detector_area_exited(area: Area2D) -> void:
	targets.erase(area)


func _on_card_drag_or_aiming_started(used_card: CardUI) -> void:
	if used_card == self:
		# Log which card has been picked up for dragging/aiming
		var picked_name := "<null>"
		if card:
			if card.title != "":
				picked_name = card.title
			elif card.id != "":
				picked_name = card.id
			else:
				picked_name = card.resource_name
		print("[CardUI] DRAG PICKUP → %s (CardUI id: %d)" % [picked_name, self.get_instance_id()])
		return
	# Any other card should be disabled while another is being dragged
	disabled = true


func _on_card_drag_or_aim_ended(used_card: CardUI) -> void:
	# Restore interactivity for non-dragged cards and ignore further processing
	if used_card != self:
		disabled = false
		if char_stats:
			playable = char_stats.can_play_card(card)
		else:
			playable = false
		return
	disabled = false
	if char_stats:
		playable = char_stats.can_play_card(card)
	else:
		playable = false
	# Check if released over a CardSlot
	var slot := _get_slot_under_mouse()
	if slot and slot.is_empty():
		slot.accept_card(self)
		return


func _on_char_stats_changed() -> void:
	if char_stats:
		playable = char_stats.can_play_card(card)
	else:
		playable = false


# Helper to find slot under mouse
func _get_slot_under_mouse() -> CardSlot:
	var mouse_pos := get_global_mouse_position()
	for n in get_tree().get_nodes_in_group("card_slots"):
		if n is CardSlot:
			var rect := Rect2(n.global_position, n.size)
			if rect.has_point(mouse_pos):
				return n
	return null
