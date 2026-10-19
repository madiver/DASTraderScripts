// Group: Utilities & toggles
// Internal: prove that this account/symbol has no open SELL orders.
// GetOrderObj returns the first matching order; advance its numeric RefNum.
// At the DAS loop limit, remain conservative and use normal cancellation staging.
$workingSells = 1;
if ($tradeContextValid != 1) { return; }
$wsRef = 0;
$wsCount = 0;
while ($wsCount < 200) {
    // DAS 5.8.4.4 ignores the strict RefNum>N form; >=N+1 advances.
    $wsNextRef = $wsRef + 1;
    $wsOrder = 0;
    $wsOrder = GetOrderObj("Acc=" + $trade.account + ",Symb=" + $trade.symbol + ",RefNum>=" + $wsNextRef);
    if (!IsObj($wsOrder)) { $workingSells = 0; return; }
    if ($wsOrder.RefNum <= $wsRef) { return; }
    if ($wsOrder.Open > 0 && $wsOrder.Side != "B") { return; }
    $wsRef = $wsOrder.RefNum;
    $wsCount = $wsCount + 1;
}
