// Group: Utilities & toggles
// Internal: prove that this account/symbol has no open SELL orders.
// GetOrderObj returns the first matching order; advance its numeric RefNum.
// At the DAS loop limit, remain conservative and use normal cancellation staging.
$workingSells = 1;
if ($tradeContextValid != 1) { return; }
if (IsObj($trade.protectionOrder)) {
    $closingOrder = $trade.protectionOrder;
    ExecHotkey("Check Order Closed");
    if ($orderClosed != 1) { return; }
}
$wsRef = $trade.Get("sellScanRef");
$wsCount = 0;
while ($wsCount < 200) {
    $wsOrder = GetOrderObj("Acc=" + $trade.account + ",Symb=" + $trade.symbol + ",RefNum>" + $wsRef);
    if (!IsObj($wsOrder)) { $trade.Set("sellScanRef", 0); $workingSells = 0; return; }
    if ($wsOrder.RefNum <= $wsRef) { return; }
    if ($wsOrder.Side != "B") {
        $closingOrder = $wsOrder;
        ExecHotkey("Check Order Closed");
        if ($orderClosed != 1) { return; }
    }
    $wsRef = $wsOrder.RefNum;
    $trade.Set("sellScanRef", $wsRef);
    $wsCount = $wsCount + 1;
}
