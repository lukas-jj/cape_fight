class_name PvpBattle
extends Node2D

@export var battle_stats: BattleStats
@export var char_stats: CharacterStats
#@export var music: AudioStream
@export var relics: RelicHandler

@onready var battle_ui: BattleUI = $BattleUI
@onready var player_handler: PlayerHandler = $PlayerHandler
@onready var enemy_handler: EnemyHandler = $EnemyHandler
@onready var player: Player = $Player


func _ready() -> void:
	enemy_handler.child_order_changed.connect(_on_enemies_child_order_changed)
	Events.enemy_turn_ended.connect(_on_enemy_turn_ended)
	
	Events.player_turn_ended.connect(player_handler.end_turn)
	Events.player_hand_discarded.connect(enemy_handler.start_turn)
	Events.player_died.connect(_on_player_died)


func start_battle() -> void:
	get_tree().paused = false
	#MusicPlayer.play(music, true)
	
	battle_ui.char_stats = char_stats
	player.stats = char_stats
	player_handler.relics = relics
	enemy_handler.setup_enemies(battle_stats)
	enemy_handler.reset_enemy_actions()
	
	relics.relics_activated.connect(_on_relics_activated)
	relics.activate_relics_by_type(Relic.Type.START_OF_COMBAT)


func _on_enemies_child_order_changed() -> void:
	if enemy_handler.get_child_count() == 0 and is_instance_valid(relics):
		relics.activate_relics_by_type(Relic.Type.END_OF_COMBAT)


func _on_enemy_turn_ended() -> void:
	# DEBUG: Show how much block the player has right after all enemy attacks have resolved.
	print("[Battle] End of enemy turn – player block:", player.stats.block)
	
	# Wait until END_OF_ENEMY_TURN statuses finish before starting the player's turn;
	# otherwise block may be reset to 0 before Braced Defense deals damage.
	var handler := player.status_handler
	if not handler.statuses_applied.is_connected(_after_enemy_end_statuses):
		handler.statuses_applied.connect(_after_enemy_end_statuses, CONNECT_ONE_SHOT)
	
	handler.apply_statuses_by_type(Status.Type.END_OF_ENEMY_TURN)


func _after_enemy_end_statuses(type: Status.Type) -> void:
	if type != Status.Type.END_OF_ENEMY_TURN:
		return
	
	player_handler.start_turn()
	enemy_handler.reset_enemy_actions()


func _on_player_died() -> void:
	Events.battle_over_screen_requested.emit("Game Over!", BattleOverPanel.Type.LOSE)
	SaveGame.delete_data()


func _on_relics_activated(type: Relic.Type) -> void:
	match type:
		Relic.Type.START_OF_COMBAT:
			player_handler.start_battle(char_stats)
			battle_ui.initialize_card_pile_ui()
		Relic.Type.END_OF_COMBAT:
			print(char_stats.resource_name)
			Events.battle_over_screen_requested.emit("Victory!", BattleOverPanel.Type.WIN)
