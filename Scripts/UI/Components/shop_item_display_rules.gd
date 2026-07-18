extends RefCounted

const INVENTORY_BADGE_MIN_COUNT := 2


static func should_show_inventory_count(count: int) -> bool:
	return count >= INVENTORY_BADGE_MIN_COUNT
