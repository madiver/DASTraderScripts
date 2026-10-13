// Group: Utilities & toggles
// Internal: prove that this account/symbol has no open SELL orders.
// GetOrderObj returns the first matching order; advance its numeric RefNum.
// At the DAS loop limit, remain conservative and use normal cancellation staging.
$workingSells = 1;
if ($tradeContextValid != 1) { return; }
$wsRef = 0;
$wsCount = 0;
while ($wsCount < 200) {
    $wsOrder = GetOrderObj("Acc=" + $trade.account + ",Symb=" + $trade.symbol + ",RefNum>" + $wsRef);
    if (!IsObj($wsOrder)) { $workingSells = 0; return; }
    if ($wsOrder.RefNum <= $wsRef) { return; }
    if ($wsOrder.Open > 0 && $wsOrder.Side != "B") { return; }
    $wsRef = $wsOrder.RefNum;
    $wsCount = $wsCount + 1;
}
