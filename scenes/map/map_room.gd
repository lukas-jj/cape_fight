class_name MapRoom
extends Area2D

signal clicked(room: Room)
signal selected(room: Room)

const ICON_SCALE_FACTOR := 2.5  # adjust this multiplier for larger icons
const ICONS := {
	Room.Type.NOT_ASSIGNED: [null, Vector2.ONE],
	Room.Type.MONSTER: [preload("res://art/tile_0103.png"), Vector2.ONE],
	Room.Type.TREASURE: [preload("res://art/tile_0089.png"), Vector2.ONE],
	Room.Type.CAMPFIRE: [preload("res://art/player_heart.png"), Vector2.ONE],
	Room.Type.SHOP: [preload("res://art/gold.png"), Vector2.ONE],
	Room.Type.BOSS: [preload("res://art/tile_0105.png"), Vector2(1.25, 1.25)],
	Room.Type.EVENT: [preload("res://art/rarity.png"), Vector2(0.9, 0.9)],
}


@onready var sprite_2d: Sprite2D = $Visuals/Sprite2D
@onready var line_2d: Line2D = $Visuals/Line2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var available := false : set = set_available
var room: Room : set = set_room

@export var ignore_room_position: bool = false

func set_available(new_value: bool) -> void:
	available = new_value
	
	if available:
		animation_player.play("highlight")
	elif not room.selected:
		animation_player.play("RESET")


func set_room(new_data: Room) -> void:
	room = new_data
	if not ignore_room_position:
		position = room.position
	if line_2d:
		line_2d.rotation_degrees = randi_range(0, 360)
	sprite_2d.texture = ICONS[room.type][0]
	# apply scale factor for larger icons
	sprite_2d.scale = ICONS[room.type][1] * ICON_SCALE_FACTOR


func show_selected() -> void:
	line_2d.modulate = Color.WHITE


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("left_mouse"):
		return

	room.selected = true
	clicked.emit(room)
	animation_player.play("select")


# Called by the AnimationPLayer when the 
# "select" animation finishes.
func _on_map_room_selected() -> void:
	selected.emit(room)
