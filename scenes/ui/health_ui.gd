class_name HealthUI
extends HBoxContainer

@export var show_max_hp: bool

@onready var health_label: Label = %HealthLabel
@onready var max_health_label: Label = %MaxHealthLabel


func update_stats(stats: Stats) -> void:
	# Debug logs to track what's happening with block
	print("[HEALTH UI] update_stats called with stats: " + str(stats))
	print("[HEALTH UI] Health: " + str(stats.health) + ", Max Health: " + str(stats.max_health))
	
	# Make sure the health label text is initially correct
	health_label.text = str(stats.health)
	max_health_label.text = "/%s" % str(stats.max_health)
	max_health_label.visible = show_max_hp
	
	# Check for block and log its value
	var has_block = false
	var block_value = 0
	
	if "block" in stats:
		block_value = stats.block
		has_block = block_value > 0
		print("[HEALTH UI] Block value: " + str(block_value) + ", Will display: " + str(has_block))
	else:
		print("[HEALTH UI] WARNING: No 'block' property found in stats!")
	
	# Only add block visual if block is greater than zero
	if has_block:
		# Append single block shield emoji with the block value
		print("[HEALTH UI] Adding block visual with shield emoji: " + str(block_value))
		health_label.text = str(stats.health) + " 🛡️" + str(block_value)
		print("[HEALTH UI] Final text: '" + health_label.text + "'")
	else:
		# Just show health without block
		print("[HEALTH UI] No block to display - resetting to health only")
		health_label.text = str(stats.health)
	
	# Verify label properties
	print("[HEALTH UI] Label visibility: " + str(health_label.visible))
	print("[HEALTH UI] Label text: '" + health_label.text + "'")
	print("[HEALTH UI] Label position: " + str(health_label.global_position))
