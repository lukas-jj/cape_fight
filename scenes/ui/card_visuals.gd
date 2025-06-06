class_name CardVisuals
extends Control

# Mapping for full speed names
const SPEED_TEXT := {
	Card.Speed.SLOW: "Slow",
	Card.Speed.NORMAL: "Normal",
	Card.Speed.FAST: "Fast",
	Card.Speed.SNAP: "Snap",
}

@export var card: Card : set = set_card

@onready var panel: Panel = $Panel
@onready var cost: Label = $Cost
@onready var icon: TextureRect = $Icon
@onready var rarity: TextureRect = $Rarity
@onready var title_label: Label = $Title
@onready var speed_label: Label = $Speed


func set_card(value: Card) -> void:
	if not is_node_ready():
		await ready

#	print("[CardVisuals] set_card called. incoming:", value.resource_name if value else "null")

	card = value

	# Gracefully handle clearing visuals when card is null
	if card == null:
#		print("[CardVisuals] value is null – clearing visuals")
		if cost:
			cost.text = ""
		if icon:
			icon.texture = null
		if rarity:
			rarity.modulate = Color.WHITE
		if title_label:
			title_label.text = ""
		if speed_label:
			speed_label.text = ""
		return

	# Update visuals with real card data
	if cost:
		cost.text = str(card.cost)
	if icon:
		icon.texture = card.icon
	if rarity:
		rarity.modulate = Card.RARITY_COLORS[card.rarity]
	if title_label:
		title_label.text = card.title
	if speed_label:
		speed_label.text = SPEED_TEXT.get(card.speed, "")

#	print("[CardVisuals] card set complete. cost label exists:", cost!=null, "icon exists:", icon!=null)
