extends Control
signal alley_chosen(room)

@export var alley_texture: Texture2D
@onready var slots: Array = [$RoomsContainer/OptionA, $RoomsContainer/OptionB, $RoomsContainer/OptionC]
var initial_positions: Array = []
var choices: Array = []

func _ready():
	$TextureRect.texture = alley_texture
	$TextureRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$RoomsContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# record UI positions and hook up clicks
	for mr in slots:
		initial_positions.append(mr.position)
		mr.clicked.connect(Callable(self, "_on_btn_pressed"))

func setup(rooms: Array) -> void:
	# fetch 3 weighted choices from WorkDayManager
	choices = WorkDayManager.generate_alley_choices()
	for i in range(slots.size()):
		var slot = slots[i]
		if i < choices.size():
			var data = choices[i]
			slot.set_available(true)
			slot.set_room(data.room)
			slot.modulate = data.alley_type ==  Color(0.5,0.5,0.8) if WorkDayManager.AlleyType.DARK  else Color(0.8,0.8,1)
			slot.position = initial_positions[i]
			slot.visible = true
		else:
			slot.visible = false

func _on_btn_pressed(room: Room) -> void:
	# pass along the chosen room, then clear choices
	emit_signal("alley_chosen", room)
	choices.clear()
