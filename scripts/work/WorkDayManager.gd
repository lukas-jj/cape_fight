extends Node

var money: int = 0
var threat_level: int = 0
var day: int = 1

const Room = preload("res://custom_resources/room.gd")
@export var battle_stats_pool: BattleStatsPool = preload("res://battles/battle_stats_pool.tres")
@export var event_room_pool: EventRoomPool = preload("res://scenes/event_rooms/event_room_pool.tres")

enum AlleyType { DARK, LIGHT }

const WEIGHT_SETS = {
	AlleyType.DARK: {
		Room.Type.MONSTER:  0.6,
		Room.Type.EVENT:    0.2,
		Room.Type.SHOP:     0.1,
		Room.Type.CAMPFIRE: 0.05,
	},
	AlleyType.LIGHT: {
		Room.Type.SHOP:     0.4,
		Room.Type.CAMPFIRE: 0.05,
		Room.Type.EVENT:    0.3,
		Room.Type.MONSTER:  0.1,
	},
}

func pick_room_type_by_alley(alley_type: int) -> Room.Type:
	# roll against cumulative weights
	var roll = randf()
	var cum = 0.0
	for t in WEIGHT_SETS[alley_type].keys():
		cum += WEIGHT_SETS[alley_type][t]
		if roll <= cum:
			return t
	return Room.Type.MONSTER

func generate_alley_choices() -> Array:
	# produce 3 random alley choices with weighted room types
	battle_stats_pool.setup()
	randomize()
	var choices = []
	for i in range(3):
		var alley_type = randi() % 2
		var room_type = pick_room_type_by_alley(alley_type)
		var room = Room.new()
		room.type = room_type
		if room_type == Room.Type.MONSTER:
			var tier = min(threat_level, battle_stats_pool.pool.size() - 1)
			room.battle_stats = battle_stats_pool.get_random_battle_for_tier(tier)
		elif room_type == Room.Type.EVENT:
			room.event_scene = event_room_pool.get_random()
		choices.append({"room": room, "alley_type": alley_type})
	return choices

func set_overtime(_hours: int):
	# removed overtime money and threat logic
	pass

func next_day():
	day += 1
	threat_level = 0
