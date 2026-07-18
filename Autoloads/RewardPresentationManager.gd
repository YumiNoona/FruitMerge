extends Node

const SUPPORTED_CURRENCIES: Array[StringName] = [&"coins", &"tickets"]

var _pending_wallet_rewards: Array[Dictionary] = []


func queue_wallet_reward(currency: StringName, amount: int) -> bool:
	if currency not in SUPPORTED_CURRENCIES or amount <= 0:
		return false
	_pending_wallet_rewards.append({"currency": currency, "amount": amount})
	return true


func take_pending_wallet_rewards() -> Array[Dictionary]:
	var rewards: Array[Dictionary] = _pending_wallet_rewards.duplicate(true)
	_pending_wallet_rewards.clear()
	return rewards


func clear_pending_wallet_rewards() -> void:
	_pending_wallet_rewards.clear()
