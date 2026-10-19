// Group: Utilities & toggles
// Conservative account/symbol cancellation barrier. Keep a cursor across long histories.
$exitOrdersClear = 0;
if ($tradeContextValid != 1) { return; }
if (IsObj($trade.exitOrder)) {
    $closingOrder = $trade.exitOrder;
    ExecHotkey("Check Order Closed");
    if ($orderClosed != 1) { $trade.exitOrder.Cancel(); return; }
}
// Submitted entry/protection objects may not yet appear in order-history searches.
$coTracked = $trade.entryOrder;
$coTrackedIndex = 0;
while ($coTrackedIndex < 2) {
    if ($coTrackedIndex == 1) { $coTracked = $trade.protectionOrder; }
    if (IsObj($coTracked)) {
        $closingOrder = $coTracked;
        ExecHotkey("Check Order Closed");
        if ($orderClosed != 1) { $coTracked.Cancel(); return; }
    }
    $coTrackedIndex = $coTrackedIndex + 1;
}
$coCount = 0;
while ($coCount < 200) {
    $coOrder = GetOrderObj("Acc=" + $trade.account + ",Symb=" + $trade.symbol + ",RefNum>" + $trade.closeScanRef);
    if (!IsObj($coOrder)) { $exitOrdersClear = 1; return; }
    if ($coOrder.RefNum <= $trade.closeScanRef) { return; }
    $closingOrder = $coOrder;
    ExecHotkey("Check Order Closed");
    if ($orderClosed != 1) { $coOrder.Cancel(); return; }
    $trade.closeScanRef = $coOrder.RefNum;
    $trade.Set("closedOrderRef", $trade.closeScanRef);
    $coCount = $coCount + 1;
}
