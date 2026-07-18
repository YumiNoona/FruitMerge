class_name ShopCatalogData
extends Resource

@export var items: Array[ShopItemData] = []


func get_items_for_category(category: StringName) -> Array[ShopItemData]:
	var result: Array[ShopItemData] = []
	for item in items:
		if item and item.category == category:
			result.append(item)
	return result


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var ids: Dictionary = {}
	for item in items:
		if not item:
			errors.append("Catalog contains an empty item")
			continue
		if item.id.is_empty():
			errors.append("Catalog item has an empty ID")
		elif ids.has(item.id):
			errors.append("Duplicate shop item ID: %s" % item.id)
		ids[item.id] = true
		if not item.is_valid_definition():
			errors.append("Invalid definition for shop item: %s" % item.id)
	return errors
