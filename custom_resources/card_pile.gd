class_name CardPile
extends Resource

signal card_pile_size_changed(cards_amount)

@export var cards: Array[Card] = []


# ─────────── Basic operations ───────────
func empty() -> bool:
	return cards.is_empty()


func draw_card() -> Card:
	var card: Card = cards.pop_front()
	card_pile_size_changed.emit(cards.size())
	return card


func add_card(card: Card) -> void:
	cards.append(card)
	card_pile_size_changed.emit(cards.size())


func shuffle() -> void:
	RNG.array_shuffle(cards)


func clear() -> void:
	cards.clear()
	card_pile_size_changed.emit(cards.size())

# ─────────── Helpers (shallow copy) ───────────
func duplicate_cards() -> Array[Card]:
	# Shallow duplicate keeps original Card resources
	var copy: Array[Card] = cards.duplicate()
	return copy


func custom_duplicate() -> CardPile:
	var new_pile: CardPile = CardPile.new()
	new_pile.cards = cards.duplicate()   # shallow copy
	return new_pile

# ─────────── Debug print ───────────
func _to_string() -> String:
	var lines: PackedStringArray = []
	for i in range(cards.size()):
		lines.append("%s: %s" % [i + 1, cards[i].id])
	return "\n".join(lines)
