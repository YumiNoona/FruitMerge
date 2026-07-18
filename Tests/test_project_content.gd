extends RefCounted


static func run() -> PackedStringArray:
	return ProjectValidator.validate_all()
