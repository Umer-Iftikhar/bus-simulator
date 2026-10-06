extends TestCase


func test_starting_balance_is_never_negative() -> void:
	assert_eq(Wallet.new(-50).balance, 0)
	assert_eq(Wallet.new(70).balance, 70)


func test_earn_and_spend() -> void:
	var wallet := Wallet.new(100)
	wallet.earn(50)
	assert_eq(wallet.balance, 150)
	assert_true(wallet.spend(120))
	assert_eq(wallet.balance, 30)


func test_cannot_overspend() -> void:
	var wallet := Wallet.new(10)
	assert_false(wallet.can_afford(11))
	assert_false(wallet.spend(11))
	assert_eq(wallet.balance, 10)


func test_negative_amounts_are_rejected() -> void:
	var wallet := Wallet.new(10)
	wallet.earn(-5)
	assert_false(wallet.spend(-5))
	assert_false(wallet.can_afford(-1))
	assert_eq(wallet.balance, 10)


func test_zero_cost_spend_succeeds_without_change_signal() -> void:
	var wallet := Wallet.new(0)
	watch_signals(wallet)
	assert_true(wallet.spend(0))
	assert_signal_not_emitted(wallet, "changed")


func test_changed_signal_carries_new_balance() -> void:
	var wallet := Wallet.new(5)
	watch_signals(wallet)
	wallet.earn(5)
	wallet.spend(3)
	assert_signal_emit_count(wallet, "changed", 2)
	assert_eq(get_signal_parameters(wallet, "changed"), [7])
