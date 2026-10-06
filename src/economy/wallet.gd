class_name Wallet
extends RefCounted
## The player's money. Amounts are whole currency units and never negative.

signal changed(balance: int)

var balance := 0


func _init(starting_balance := 0) -> void:
	balance = maxi(starting_balance, 0)


func earn(amount: int) -> void:
	if amount <= 0:
		return
	balance += amount
	changed.emit(balance)


func can_afford(amount: int) -> bool:
	return amount >= 0 and balance >= amount


## Deducts [param amount] if affordable. Returns false (and changes nothing) otherwise.
func spend(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	if amount == 0:
		return true
	balance -= amount
	changed.emit(balance)
	return true
