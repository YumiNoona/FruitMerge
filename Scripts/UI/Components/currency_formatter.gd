class_name CurrencyFormatter
extends RefCounted


static func format_amount(amount: int) -> String:
	var magnitude := absi(amount)
	if magnitude < 1000:
		return str(amount)
	var divisor := 1000.0
	var suffix := "K"
	if magnitude >= 1_000_000:
		divisor = 1_000_000.0
		suffix = "M"
	var scaled := floorf((float(magnitude) / divisor) * 10.0) / 10.0
	var number_text := "%d" % int(scaled) if is_equal_approx(scaled, floorf(scaled)) else "%.1f" % scaled
	return "%s%s%s" % ["-" if amount < 0 else "", number_text, suffix]
