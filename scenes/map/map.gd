# Map.gd
class_name Map
extends Node2D


const ALLEY_ROW_SCENE = preload("res://scenes/map/AlleyRow.tscn")
@onready var map_generator: MapGenerator = $MapGenerator

@onready var alley_container: VBoxContainer = $AlleyContainer

var map_data: Array = []
var floors_climbed: int = 0
var last_room

func _ready() -> void:
	# Called by Run.gd after WorkPhase
	pass

func generate_new_map() -> void:
	floors_climbed = 0
	map_data = map_generator.generate_map()
	_build_rows()
	unlock_floor(0)
	show_map()

func _build_rows() -> void:
	for child in alley_container.get_children():
		child.queue_free()
	for floor_rooms in map_data:
		var row = ALLEY_ROW_SCENE.instantiate()
		row.alley_texture = preload("res://assets/allewaypixel3.png")
		alley_container.add_child(row)
		row.setup(floor_rooms)
		row.alley_chosen.connect(Callable(self, "_on_room_selected"))

func _on_room_selected(room) -> void:
	last_room = room
	floors_climbed += 1
	Events.map_exited.emit(room)

func unlock_floor(index: int) -> void:
	# show rows up to the unlocked floor, hide the rest
	for i in range(alley_container.get_child_count()):
		var row = alley_container.get_child(i)
		row.visible = i <= index

func show_map() -> void:
	visible = true
	$Camera2D.enabled = true

func hide_map() -> void:
	visible = false
	$Camera2D.enabled = false
