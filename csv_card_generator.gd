# CSV Card Generator – Streak Draftable Cards Only
# --------------------------------------------------------------
# Generates .tres Card resources for Streak's draftable cards
# based on `Full_Character_Decks.csv`, and updates the
# `streak_draftable_cards.tres` pile.
# --------------------------------------------------------------

extends EditorScript

const CSV_PATH := "res://Full_Character_Decks.csv"
const CARD_SCRIPT      : Script = preload("res://custom_resources/card.gd")
const CARD_PILE_SCRIPT : Script = preload("res://custom_resources/card_pile.gd")

# Map CSV "Type" to Card.Type
const TYPE_MAP := {
	"Attack": Card.Type.ATTACK,
	"Block":  Card.Type.SKILL,
	"Block/Buff": Card.Type.SKILL,
	"Buff":   Card.Type.SKILL,
	"Debuff": Card.Type.SKILL,
	"Utility":Card.Type.SKILL,
	"Power":  Card.Type.POWER,
}

const TARGET_DEFAULT := {
	Card.Type.ATTACK: Card.Target.SINGLE_ENEMY,
	Card.Type.SKILL:  Card.Target.SELF,
	Card.Type.POWER:  Card.Target.SELF,
}

func _run() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		push_error("[CSVCardGen] CSV not found at %s" % CSV_PATH)
		return

	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	file.get_line() # discard header

	var defs : Array = []

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var cols := line.split(",", false)
		if cols.size() < 7:
			push_warning("[CSVCardGen] Malformed row: %s" % line)
			continue

		var character := cols[0].strip_edges()
		var deck_type := cols[1].strip_edges()
		if character != "Streak" or deck_type != "Draft":
			continue

		var card_name   := cols[2].strip_edges()
		var speed_str := cols[3].strip_edges().to_lower()
		var cost := int(cols[4])
		var csv_type := cols[5].strip_edges()
		var effect := cols[6].strip_edges()

		# Determine enums
		var card_type = TYPE_MAP.get(csv_type, Card.Type.SKILL)
		var target = TARGET_DEFAULT.get(card_type, Card.Target.SELF)

		var speed_enum := Card.Speed.NORMAL
		match speed_str:
			"slow":
				speed_enum = Card.Speed.SLOW
			"fast":
				speed_enum = Card.Speed.FAST
			"snap":
				speed_enum = Card.Speed.SNAP

		var id := "%s_%s" % [character.to_lower(), card_name.to_lower().replace(" ", "_")]

		defs.append({
			"id": id,
			"name": card_name,
			"type": card_type,
			"target": target,
			"cost": cost,
			"speed": speed_enum,
			"tooltip": "[center]%s[/center]" % effect,
		})

	file.close()

	if defs.is_empty():
		push_warning("[CSVCardGen] No Streak draftable rows found.")
		return

	_create_streak_resources(defs)
	print("[CSVCardGen] Streak draftable cards generated ✔ (%d)" % defs.size())


func _create_streak_resources(defs:Array) -> void:
	var base_dir := "res://characters/streak/"
	var cards_dir := base_dir + "cards/"
	var dir := DirAccess.open(base_dir)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(base_dir)
	DirAccess.make_dir_recursive_absolute(cards_dir)

	var saved_cards : Dictionary = {}

	for d in defs:
		var res_path: String = cards_dir + d["id"] + ".tres"
		var card_res: Card = _load_or_create(res_path)

		card_res.script       = CARD_SCRIPT
		card_res.id           = d["id"]
		card_res.title        = d["name"]
		card_res.type         = d["type"]
		card_res.rarity       = Card.Rarity.COMMON
		card_res.target       = d["target"]
		card_res.cost         = d["cost"]
		card_res.speed        = d["speed"]
		card_res.tooltip_text = d["tooltip"]

		var err := ResourceSaver.save(card_res, res_path)
		if err != OK:
			push_error("[CSVCardGen] Failed to save %s (err=%s)" % [res_path, err])
		else:
			saved_cards[d["id"]] = load(res_path)

	# Build CardPile
	var pile_path := base_dir + "streak_draftable_cards.tres"
	var pile : Resource = _load_or_create(pile_path, CARD_PILE_SCRIPT)
	pile.cards.clear()
	for d in defs:
		pile.cards.append(saved_cards[d["id"]])

	var pile_err := ResourceSaver.save(pile, pile_path)
	if pile_err != OK:
		push_error("[CSVCardGen] Failed to save pile (%s)" % pile_err)


func _load_or_create(path:String, script:Script=null):
	if ResourceLoader.exists(path):
		return load(path)
	return script.new() if script else CARD_SCRIPT.new()
