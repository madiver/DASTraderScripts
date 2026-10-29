// Group: Utilities & toggles
// Internal: called with a fresh signed context by Timer Entry Handler.
// Track actual short fills; never infer a fill from order submission.
if ($tradeContextValid != 1 || $tradePositionValid != 1 || $trade.shortWatch != 1) { return; }
if ($trade.tpCancelPending == 1) { return; }
$tsEntryOrder = $trade.shortEntryOrder;
if ($trade.shortEntryPending == 1 && IsObj($tsEntryOrder)) {
    $tsEntryOrder.GetInfo();
    if ($tsEntryOrder.Open == 0 || $posNow < $trade.shortEntryPosBefore) {
        // Continue watching for later fills even after the first partial fill.
        $trade.shortEntryPending = 0;
    } else {
        $trade.shortEntryTicks = $trade.shortEntryTicks + 1;
        $shortEntryElapsed = GetSecond() - $trade.shortEntryStarted;
        if ($shortEntryElapsed < 0) { $shortEntryElapsed = $shortEntryElapsed + 86400; }
        if ($trade.shortEntryTimeoutSeconds > 0 && $shortEntryElapsed >= $trade.shortEntryTimeoutSeconds) {
            $tsEntryOrder.Cancel();
            // Keep checking until cancellation (or a racing fill) is visible.
            return;
        }
    }
}
$tsStopOrder = $trade.Get("shortStopOrder");
if ($posNow >= 0) {
    if ($posNow == 0 && $trade.shortEntryPending == 1) { return; }
    // A short may have been closed/reversed externally. Cancel only its orders.
    if (IsObj($tsEntryOrder)) {
        $tsEntryOrder.GetInfo();
        if ($tsEntryOrder.Open != 0) { $tsEntryOrder.Cancel(); return; }
    }
    if (IsObj($tsStopOrder)) {
        $tsStopOrder.GetInfo();
        if ($tsStopOrder.Open != 0) { $tsStopOrder.Cancel(); return; }
    }
    if ($trade.shortCoverPending == 1) {
        // A racing stop/external close can flatten before the cover finishes.
        $tradeAccountObj.CancelOrder("BUY", $trade.symbol, 0);
        ExecHotkey("Check Working Buys");
        if ($workingBuys != 0) { return; }
    }
    $trade.Set("shortStopOrder", 0);
    $trade.shortWatch = 0;
    $trade.shortCoverPending = 0;
    $trade.stopArmed = 0;
    $trade.lastStop = 0;
    if ($posNow == 0) { ExecHotkey("Clear Trade State"); }
    else { $trade.active = 0; }
    return;
}
if ($avgNow <= 0) { return; }
$tsQty = 0 - $posNow;
if ($trade.shortCoverPending == 1) {
    ExecHotkey("Check Working Buys");
    if ($workingBuys != 0) { return; }
    $trade.shortCoverPending = 0;
}
if ($useAutoStop == "Yes") {
    $tsNeedStop = 1;
    if ($trade.stopArmed == 1 && $trade.shortStopQty == $tsQty && $trade.shortStopAvg == $avgNow) { $tsNeedStop = 0; }
    if ($tsNeedStop == 1 && IsObj($tsStopOrder)) {
        $tsStopOrder.GetInfo();
        // A partially executing stop already covers its remaining shares.
        if ($tsStopOrder.Open == $tsQty && $tsStopOrder.Open > 0 && $trade.shortStopAvg == $avgNow) {
            $trade.shortStopQty = $tsQty;
            $tsNeedStop = 0;
        }
    }
    if ($tsNeedStop == 1) {
        ExecHotkey("Check Working Buys");
        if ($workingBuys != 0) { return; }
        if (IsObj($tsStopOrder)) {
            $tsStopOrder.GetInfo();
            if ($tsStopOrder.Open != 0) { $tsStopOrder.Cancel(); return; }
        }
        SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
        SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
        SetVar("SHORT_STOP_TIMER", 1);
        SetVar("SHORT_STOP_BE", $trade.shortStopBE);
        $timerMode = 1;
        ExecHotkey("Set Auto Stop");
        if ($stopSubmitted != 1) { return; }
    }
}
if ($useTakeProfit == "Yes") {
    // Do not repeat a completed TP without new shares/average or a manual RESET.
    if ($tsQty > $trade.shortTpQty || $avgNow != $trade.shortTpAvg) { $trade.shortTpDone = 0; }
    $tsTpExists = 0;
    if ($trade.tpName != "") {
        $tsTpAlert = GetAlertObj($trade.tpName);
        if (IsObj($tsTpAlert)) { $tsTpExists = 1; }
    }
    if ($trade.shortTpDone != 1 && ($tsTpExists != 1 || $tsQty != $trade.shortTpQty || $avgNow != $trade.shortTpAvg)) {
        SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
        SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
        SetVar("TP_EXPECTED_DIRECTION", -1);
        $timerMode = 1;
        ExecHotkey("Set Take Profit");
    }
}
