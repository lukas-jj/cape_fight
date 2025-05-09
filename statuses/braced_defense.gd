class_name BracedDefenseStatus
extends Status

# Deals damage to all enemies equal to the block remaining at the END of the enemy turn.

# Use the player's current block at end of enemy turn; no caching needed.

func apply_status(target: Node) -> void:
	# StatusHandler calls this automatically for END_OF_ENEMY_TURN statuses.
	print("[BracedDefenseStatus] apply_status() called. Target:", target)
	on_end_of_enemy_turn(target)


func on_end_of_enemy_turn(target: Node) -> void:
	print("[BracedDefenseStatus] on_end_of_enemy_turn() called. Target:", target)
	if target == null:
		push_warning("[BracedDefenseStatus] Target is null – aborting.")
		return

	if not target.stats or target.stats == null:
		push_warning("[BracedDefenseStatus] Target has no stats – aborting.")
		return

	var damage_amount: int = target.stats.block
	print("[BracedDefenseStatus] Damage amount (current block):", damage_amount)
	if damage_amount <= 0:
		# Nothing to do if no block is left.
		status_applied.emit(self)
		return

	# Damage all enemies by the remaining block amount.
	var enemies: Array = target.get_tree().get_nodes_in_group("enemies")
	print("[BracedDefenseStatus] Enemies to damage:", enemies.size())
	for enemy in enemies:
		if enemy and enemy.has_method("take_damage"):
			print("[BracedDefenseStatus] Dealing", damage_amount, "damage to", enemy.name)
			enemy.take_damage(damage_amount, Modifier.Type.DMG_TAKEN)

	# Let StatusHandler handle duration/expiration via the status_applied signal.
	print("[BracedDefenseStatus] Emitting status_applied – duration remaining:", duration)
	status_applied.emit(self)


func initialize_status(target: Node) -> void:
	if not target or not target.stats:
		push_warning("[BracedDefenseStatus] initialize_status() – target missing stats, aborting bind")
		return

	print("[BracedDefenseStatus] initialize_status() – no initialization needed")

	# No listeners or stored block needed.
