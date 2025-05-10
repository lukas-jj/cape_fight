extends Control

# Simple stub for VS-AI screen. Sets up two players, draws hands and prints round resolution to output.
# TODO: Replace prints with full UI animations & interactions.
# Local player data container; renamed to avoid clash with global Player class
class BattlePlayer:
	var name: String
	var hp: int = 30
	var block: int = 0
	var hand: Array[Card] = []
	var selected := []
	var ordered := []
	var energy: int = 3
	
	func _init(p_name: String):
		name = p_name
	
func _ready() -> void:
	print("VS-AI scene loaded. Placeholder logic running…")
	# Build minimal card pool from existing resources (all Streak commons)
	var card_paths := [
		"res://characters/streak/cards/streak_quick_strike.tres",
		"res://characters/streak/cards/streak_dash_kick.tres",
		"res://characters/streak/cards/streak_adrenaline_kick.tres",
		"res://characters/streak/cards/streak_block.tres",
	]
	var pool: Array[Card] = []
	for p in card_paths:
		if ResourceLoader.exists(p):
			var res := load(p)
			if res is Card:
				pool.append(res)
	
	if pool.is_empty():
		print("No cards found for stub pool. Aborting.")
		return
	
	var player := BattlePlayer.new("You")
	var enemy := BattlePlayer.new("AI")
	player.hand = pool.duplicate()
	enemy.hand = pool.duplicate()
	
	print("Player hand:")
	for c in player.hand:
		print(" ‑", c.title)
	
	# Very naive selection/resolution for demo
	player.selected = player.hand.slice(0, 3)
	enemy.selected = enemy.hand.slice(0, 3)
	player.ordered = player.selected
	enemy.ordered = enemy.selected
	
	_resolve_round(player, enemy)

func _compare_card(a: Card, b: Card) -> int:
	# Higher priority returns -1 to sort ascending
	if a.speed != b.speed:
		return int(a.speed) - int(b.speed)
	return int(a.type) - int(b.type)

func _resolve_round(p1: BattlePlayer, p2: BattlePlayer) -> void:
	print("Resolving round…")
	for i in range(3):
		var card_a: Card = p1.ordered[i]
		var card_b: Card = p2.ordered[i]
		print("Slot %d: %s vs %s" % [i + 1, card_a.title, card_b.title])
	print("Round complete.")
