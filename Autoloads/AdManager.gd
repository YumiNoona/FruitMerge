extends Node

# Game-side bridge for rewarded ads and the permanent no-ads entitlement. A
# Google Mobile Ads / Google Play Billing Android plugin calls complete_* only
# after its platform callback confirms success.

signal ad_message(message: String)
signal rewarded_ad_availability_changed(available: bool, message: String)
signal rewarded_powerup_completed(item_id: StringName, amount: int)
signal no_ads_changed(owned: bool)

const NO_ADS_PRODUCT_ID := "fruit_merge_no_ads"
const DEBUG_AD_DELAY := 0.8

var _rewarded_ad_busy := false
var _platform_bridge: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_find_platform_bridge")


func _find_platform_bridge() -> void:
	# A mobile implementation can register as /root/MobileMonetization and
	# expose show_rewarded_ad / purchase_no_ads.
	_platform_bridge = get_tree().root.get_node_or_null("MobileMonetization")
	rewarded_ad_availability_changed.emit(is_rewarded_ad_available(), get_rewarded_ad_message())


func is_rewarded_ad_available() -> bool:
	if _rewarded_ad_busy:
		return false
	if is_instance_valid(_platform_bridge) and _platform_bridge.has_method("show_rewarded_ad"):
		return true
	# Never grant currency automatically in a release build without a real ad
	# completion callback. Debug builds retain a visible test path.
	return OS.is_debug_build()


func get_rewarded_ad_message() -> String:
	if is_instance_valid(_platform_bridge) and _platform_bridge.has_method("show_rewarded_ad"):
		return "Watch a short video to earn the shown reward."
	if OS.is_debug_build():
		return "Debug reward preview: grants the shown reward after a short test delay."
	return "Rewarded ads will be available after the mobile ads bridge is connected."


func is_rewarded_ad_busy() -> bool:
	return _rewarded_ad_busy


func request_rewarded_ticket(amount := 1) -> void:
	if _rewarded_ad_busy:
		return
	if is_instance_valid(_platform_bridge) and _platform_bridge.has_method("show_rewarded_ad"):
		_rewarded_ad_busy = true
		rewarded_ad_availability_changed.emit(false, "Loading your reward video…")
		_platform_bridge.show_rewarded_ad(&"ticket", amount)
		return
	if OS.is_debug_build():
		_run_debug_reward(amount)
		return
	ad_message.emit("Rewarded ads are not connected in this build yet.")
	rewarded_ad_availability_changed.emit(false, get_rewarded_ad_message())


func request_rewarded_powerup(item_id: StringName, amount := 1) -> void:
	if _rewarded_ad_busy:
		return
	if not PowerLoadoutManager.get_item_data(item_id) or amount <= 0:
		ad_message.emit("That power-up reward is unavailable.")
		return
	if is_instance_valid(_platform_bridge) and _platform_bridge.has_method("show_rewarded_ad"):
		_rewarded_ad_busy = true
		rewarded_ad_availability_changed.emit(false, "Loading your reward video…")
		# The reward key lets the platform callback return the exact selected power.
		_platform_bridge.show_rewarded_ad(item_id, amount)
		return
	if OS.is_debug_build():
		_run_debug_powerup_reward(item_id, amount)
		return
	ad_message.emit("Rewarded ads are not connected in this build yet.")
	rewarded_ad_availability_changed.emit(false, get_rewarded_ad_message())


func _run_debug_reward(amount: int) -> void:
	_rewarded_ad_busy = true
	ad_message.emit("Test reward video complete — your ticket is on its way!")
	rewarded_ad_availability_changed.emit(false, "Playing test reward…")
	await get_tree().create_timer(DEBUG_AD_DELAY, true, false, true).timeout
	complete_rewarded_ticket(amount)


func _run_debug_powerup_reward(item_id: StringName, amount: int) -> void:
	_rewarded_ad_busy = true
	ad_message.emit("Playing test reward video…")
	rewarded_ad_availability_changed.emit(false, "Playing test reward…")
	await get_tree().create_timer(DEBUG_AD_DELAY, true, false, true).timeout
	complete_rewarded_powerup(item_id, amount)


# Call from the ad SDK's reward-earned callback, not merely the close callback.
func complete_rewarded_ticket(amount: int) -> void:
	_rewarded_ad_busy = false
	EconomyManager.add_tickets(maxi(1, amount))
	SaveManager.save_game()
	ad_message.emit("Sweet! +%d ticket%s" % [maxi(1, amount), "" if amount == 1 else "s"])
	rewarded_ad_availability_changed.emit(is_rewarded_ad_available(), get_rewarded_ad_message())


# Call from the ad SDK's reward-earned callback with the reward key supplied to
# show_rewarded_ad. Closing/skipping the video must call cancel_rewarded_ad.
func complete_rewarded_powerup(item_id: StringName, amount: int = 1) -> void:
	_rewarded_ad_busy = false
	var granted_amount := maxi(1, amount)
	if not EconomyManager.grant_powerup(item_id, granted_amount):
		ad_message.emit("That power-up reward could not be delivered.")
		rewarded_ad_availability_changed.emit(is_rewarded_ad_available(), get_rewarded_ad_message())
		return
	var display_name := PowerLoadoutManager.get_display_name(item_id)
	ad_message.emit("Sweet! +%d %s" % [granted_amount, display_name])
	rewarded_powerup_completed.emit(item_id, granted_amount)
	rewarded_ad_availability_changed.emit(is_rewarded_ad_available(), get_rewarded_ad_message())


func cancel_rewarded_ad(message := "No reward this time — the video was skipped.") -> void:
	_rewarded_ad_busy = false
	ad_message.emit(message)
	rewarded_ad_availability_changed.emit(is_rewarded_ad_available(), get_rewarded_ad_message())


func has_no_ads() -> bool:
	return bool(SaveManager.get_setting("no_ads_purchased", false))


func request_no_ads_purchase() -> void:
	if has_no_ads():
		ad_message.emit("Your garden is already ad-free. Thank you!")
		return
	if is_instance_valid(_platform_bridge) and _platform_bridge.has_method("purchase_no_ads"):
		_platform_bridge.purchase_no_ads(NO_ADS_PRODUCT_ID)
		return
	ad_message.emit("Google Play Billing needs to be connected before checkout can open.")


# Call only after Google Play reports a verified, acknowledged purchase.
func complete_no_ads_purchase() -> void:
	SaveManager.set_setting("no_ads_purchased", true)
	no_ads_changed.emit(true)
	ad_message.emit("No ads unlocked — enjoy the peaceful orchard!")


func restore_no_ads_purchase() -> void:
	if is_instance_valid(_platform_bridge) and _platform_bridge.has_method("restore_no_ads_purchase"):
		_platform_bridge.restore_no_ads_purchase(NO_ADS_PRODUCT_ID)
	else:
		ad_message.emit("Purchase restore will be available with the Google Play Billing bridge.")
