class_name Run
extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const BATTLE_REWARD_SCENE := preload("res://scenes/battle_reward/battle_reward.tscn")
const CAMPFIRE_SCENE := preload("res://scenes/campfire/campfire.tscn")
const SHOP_SCENE := preload("res://scenes/shop/shop.tscn")
const TREASURE_SCENE = preload("res://scenes/treasure/treasure.tscn")
const WIN_SCREEN_SCENE := preload("res://scenes/win_screen/win_screen.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const INTRO_SCENE := preload("res://scenes/IntroScene.tscn")
const ALLEY_SCENE := preload("res://scenes/map/AlleyRow.tscn")

@export var run_startup: RunStartup

@onready var map: Map = $Map
@onready var current_view: Node = $CurrentView
@onready var health_ui: HealthUI = %HealthUI
@onready var gold_ui: GoldUI = %GoldUI
@onready var relic_handler: RelicHandler = %RelicHandler
@onready var relic_tooltip: RelicTooltip = %RelicTooltip
@onready var deck_button: CardPileOpener = %DeckButton
@onready var deck_view: CardPileView = %DeckView
@onready var pause_menu: PauseMenu = $PauseMenu

@onready var battle_button: Button = %BattleButton
@onready var campfire_button: Button = %CampfireButton
@onready var map_button: Button = %MapButton
@onready var rewards_button: Button = %RewardsButton
@onready var shop_button: Button = %ShopButton
@onready var treasure_button: Button = %TreasureButton

var stats: RunStats
var character: CharacterStats
var save_data: SaveGame
var alleys_visited: int = 0

func _ready() -> void:
	if not run_startup:
		return
	
	pause_menu.save_and_quit.connect(
		func():
			get_tree().change_scene_to_file(MAIN_MENU_PATH)
	)
	
	match run_startup.type:
		RunStartup.Type.NEW_RUN:
			character = run_startup.picked_character.create_instance()
			_start_run()
		RunStartup.Type.CONTINUED_RUN:
			_load_run()


func _start_run() -> void:
	stats = RunStats.new()
	
	_setup_event_connections()
	_setup_top_bar()
	
	# show a custom intro scene per character if set, otherwise use boss intro
	var scene_to_show = character.intro_scene if character.intro_scene else INTRO_SCENE
	var intro_scene = _change_view(scene_to_show)
	intro_scene.connect("proceed", Callable(self, "_on_intro_scene_proceed"))
	

func _save_run(was_on_map: bool) -> void:
	save_data.rng_seed = RNG.instance.seed
	save_data.rng_state = RNG.instance.state
	save_data.run_stats = stats
	save_data.char_stats = character
	save_data.current_deck = character.deck
	save_data.current_health = character.health
	save_data.relics = relic_handler.get_all_relics()
	save_data.last_room = map.last_room
	save_data.map_data = map.map_data.duplicate()
	save_data.floors_climbed = map.floors_climbed
	save_data.was_on_map = was_on_map
	save_data.save_data()


func _load_run() -> void:
	save_data = SaveGame.load_data()
	assert(save_data, "Couldn't load last save")
	
	RNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
	stats = save_data.run_stats
	character = save_data.char_stats
	character.deck = save_data.current_deck
	character.health = save_data.current_health
	relic_handler.add_relics(save_data.relics)
	_setup_top_bar()
	_setup_event_connections()
	
	map.load_map(save_data.map_data, save_data.floors_climbed, save_data.last_room)
	if save_data.last_room and not save_data.was_on_map:
		_on_map_exited(save_data.last_room)


func _change_view(scene: PackedScene) -> Node:
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	get_tree().paused = false
	var new_view := scene.instantiate()
	current_view.add_child(new_view)
	map.hide_map()
	
	return new_view


func _show_map() -> void:
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()

	map.show_map()
	#map.unlock_floor()
	
	_save_run(true)


func _setup_event_connections() -> void:
	Events.battle_won.connect(_on_battle_won)
	Events.battle_reward_exited.connect(_on_room_complete)
	Events.campfire_exited.connect(_on_room_complete)
	Events.map_exited.connect(_on_map_exited)
	Events.shop_exited.connect(_on_room_complete)
	Events.treasure_room_exited.connect(_on_treasure_room_exited)
	Events.event_room_exited.connect(_on_room_complete)
	
	battle_button.pressed.connect(_change_view.bind(BATTLE_SCENE))
	campfire_button.pressed.connect(_change_view.bind(CAMPFIRE_SCENE))
	map_button.pressed.connect(_show_map)
	rewards_button.pressed.connect(_change_view.bind(BATTLE_REWARD_SCENE))
	shop_button.pressed.connect(_change_view.bind(SHOP_SCENE))
	treasure_button.pressed.connect(_change_view.bind(TREASURE_SCENE))


func _setup_top_bar():
	character.stats_changed.connect(health_ui.update_stats.bind(character))
	health_ui.update_stats(character)
	gold_ui.run_stats = stats
	
	relic_handler.add_relic(character.starting_relic)
	Events.relic_tooltip_requested.connect(relic_tooltip.show_tooltip)
	
	deck_button.card_pile = character.deck
	deck_view.card_pile = character.deck
	deck_button.pressed.connect(deck_view.show_current_view.bind("Deck"))


func _show_regular_battle_rewards() -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
	reward_scene.run_stats = stats
	reward_scene.character_stats = character

	reward_scene.add_gold_reward(map.last_room.battle_stats.roll_gold_reward())
	reward_scene.add_card_reward()


func _on_battle_room_entered(room: Room) -> void:
	var battle_scene: Battle = _change_view(BATTLE_SCENE) as Battle
	battle_scene.char_stats = character
	battle_scene.battle_stats = room.battle_stats
	battle_scene.relics = relic_handler
	battle_scene.start_battle()


func _on_treasure_room_entered() -> void:
	var treasure_scene := _change_view(TREASURE_SCENE) as Treasure
	treasure_scene.relic_handler = relic_handler
	treasure_scene.char_stats = character
	treasure_scene.generate_relic()


func _on_treasure_room_exited(relic: Relic) -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as BattleReward
	reward_scene.run_stats = stats
	reward_scene.character_stats = character
	reward_scene.relic_handler = relic_handler
	
	reward_scene.add_relic_reward(relic)


func _on_campfire_entered() -> void:
	var campfire := _change_view(CAMPFIRE_SCENE) as Campfire
	campfire.char_stats = character


func _on_shop_entered() -> void:
	var shop := _change_view(SHOP_SCENE) as Shop
	shop.char_stats = character
	shop.run_stats = stats
	shop.relic_handler = relic_handler
	Events.shop_entered.emit(shop)
	shop.populate_shop()


func _on_event_room_entered(room: Room) -> void:
	var event_room := _change_view(room.event_scene) as EventRoom
	event_room.character_stats = character
	event_room.run_stats = stats
	event_room.setup()


func _on_battle_won() -> void:
	if map.floors_climbed == MapGenerator.FLOORS:
		var win_screen := _change_view(WIN_SCREEN_SCENE) as WinScreen
		win_screen.character = character
		SaveGame.delete_data()
	else:
		_show_regular_battle_rewards()


func _on_map_exited(room: Room) -> void:
	_save_run(false)
	map.last_room = room  # ensure last_room isn’t Nil for reward lookup
	match room.type:
		Room.Type.MONSTER:
			_on_battle_room_entered(room)
		Room.Type.TREASURE:
			_on_treasure_room_entered()
		Room.Type.CAMPFIRE:
			_on_campfire_entered()
		Room.Type.SHOP:
			_on_shop_entered()
		Room.Type.BOSS:
			_on_battle_room_entered(room)
		Room.Type.EVENT:
			_on_event_room_entered(room)


func _on_intro_scene_proceed() -> void:
	# after boss overtime GIF, start map flow
	alleys_visited = 0
	_show_next_alley()
	map.show_map()


func _show_next_alley() -> void:
	var alley = _change_view(ALLEY_SCENE)
	alley.connect("alley_chosen", Callable(self, "_on_alley_chosen"))
	alley.setup(WorkDayManager.generate_alley_choices())
	map.show_map()


func _on_alley_chosen(room: Room) -> void:
	alleys_visited += 1
	map.last_room = room
	match room.type:
		Room.Type.MONSTER:
			_on_battle_room_entered(room)
		Room.Type.TREASURE:
			_on_treasure_room_entered()
		Room.Type.CAMPFIRE:
			_on_campfire_entered()
		Room.Type.SHOP:
			_on_shop_entered()
		Room.Type.EVENT:
			_on_event_room_entered(room)

func _on_room_complete() -> void:
	if alleys_visited < 3:
		_show_next_alley()
	elif alleys_visited == 3:
		# final alley complete → go home
		var home_scene = _change_view(CAMPFIRE_SCENE)
		# override home background
		var bg_sprite = home_scene.get_node("Sprite2D") as Sprite2D
		bg_sprite.texture = preload("res://art/imahomege.png")
		# relabel title to Home
		var title_label = home_scene.get_node("UILayer/UI/Title")
		title_label.text = "Home"
		home_scene.char_stats = character
		# reroute campfire exit to home handler
		Events.campfire_exited.disconnect(_on_room_complete)
		Events.campfire_exited.connect(_on_home_exited)
	else:
		# fallback: start new day
		WorkDayManager.next_day()
		var scene_to_show = character.intro_scene if character.intro_scene else INTRO_SCENE
		var intro_scene = _change_view(scene_to_show)
		intro_scene.connect("proceed", Callable(self, "_on_intro_scene_proceed"))
		# restore campfire exit for alley loop
		Events.campfire_exited.disconnect(_on_home_exited)
		Events.campfire_exited.connect(_on_room_complete)

func _on_home_exited() -> void:
	# after resting at home, advance day and restart work phase
	WorkDayManager.next_day()
	var scene_to_show = character.intro_scene if character.intro_scene else INTRO_SCENE
	var intro_scene = _change_view(scene_to_show)
	intro_scene.connect("proceed", Callable(self, "_on_intro_scene_proceed"))
	# restore campfire exit for alley loop
	Events.campfire_exited.disconnect(_on_home_exited)
	Events.campfire_exited.connect(_on_room_complete)
