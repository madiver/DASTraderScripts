// Group: Utilities & toggles
// Internal: prove no other BUY is working before arming/resizing a short stop.
// The tracked stop is canceled and acknowledged separately by the caller.
$workingBuys = 1;
if ($tradeContextValid != 1) { return; }
$wbOwnedRef = 0;
$wbOwnedOrder = $trade.Get("shortStopOrder");
if (IsObj($wbOwnedOrder)) { $wbOwnedRef = $wbOwnedOrder.RefNum; }
$wbRef = $trade.shortBuyScanRef;
$wbCount = 0;
while ($wbCount < 200) {
    $wbNextRef = $wbRef + 1;
    $wbOrder = GetOrderObj("Acc=" + $trade.account + ",Symb=" + $trade.symbol + ",RefNum>=" + $wbNextRef);
    if (!IsObj($wbOrder)) { $trade.shortBuyScanRef = 0; $workingBuys = 0; return; }
    if ($wbOrder.RefNum <= $wbRef) { $trade.shortBuyScanRef = 0; return; }
    if ($wbOrder.Open > 0 && $wbOrder.Side == "B" && $wbOrder.RefNum != $wbOwnedRef) {
        $trade.shortBuyScanRef = 0;
        return;
    }
    $wbRef = $wbOrder.RefNum;
    $wbCount = $wbCount + 1;
}
// Resume next tick rather than exceed DAS's per-loop limit or assume no cover.
$trade.shortBuyScanRef = $wbRef;
