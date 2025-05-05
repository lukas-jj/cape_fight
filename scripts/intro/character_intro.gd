extends Control
signal proceed()

@onready var label: Label = $Label
@onready var continue_button: Button = $ContinueButton

func _ready():
	# ignore in editor
	if Engine.is_editor_hint():
		return

	# find Run node in the tree
	var curr = self
	while curr:
		if curr is Run:
			# Run.gd has class_name Run
			var run_node = curr
			break
		curr = curr.get_parent()

	# display character name
	if run_node and run_node.character:
		label.text = run_node.character.character_name
	
	# connect continue
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed():
	emit_signal("proceed")
