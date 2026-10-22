class_name DeckQueue
extends RefCounted
## Only the next three cards are selectable; removing one immediately reveals the next.
var cards: Array = []

func reset(sequence: Array) -> void:
	cards.clear()
	for color_id in sequence:
		cards.append(int(color_id))

func visible_cards() -> Array:
	return cards.slice(0, mini(3, cards.size()))

func take(index: int) -> int:
	if index < 0 or index >= mini(3, cards.size()):
		return -1
	var color_id = int(cards[index])
	cards.remove_at(index)
	return color_id

