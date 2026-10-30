// Group: Utilities & toggles
// Internal: called with a fresh signed context by Timer Entry Handler.
// Track actual short fills; never infer a fill from order submission.
if ($tradeContextValid != 1 || $tradePositionValid != 1 || $trade.shortWatch != 1) { return; }
if ($trade.tpCancelPending == 1) { return; }
$tsEntryTemplate = $trade.shortEntryOrder;
$tsEntryOrder = 0;
// Send()'s object can remain an open submission template after rejection.
// Read the actual recorded order by its scoped reference instead of trusting
// that template's Open/GetInfo, including when cleaning a later flat position.
if (IsObj($tsEntryTemplate)) {
    if ($tsEntryTemplate.RefNum > 0) {
        $tsEntryOrder = GetOrderObj("Acc=" + $trade.account + ",Symb=" + $trade.symbol + ",RefNum=" + $tsEntryTemplate.RefNum);
    }
}
$shortEntryElapsed = GetSecond() - $trade.shortEntryStarted;
if ($shortEntryElapsed < 0) { $shortEntryElapsed = $shortEntryElapsed + 86400; }
if ($trade.shortEntryPending == 1 && !IsObj($tsEntryOrder) && $posNow >= $trade.shortEntryPosBefore) {
    // Missing history is not immediate proof of rejection. Give publication
    // two seconds, request cancellation of this submission, then require two
    // complete empty SELL scans on distinct seconds. An accepted working order
    // (even one whose reference was not returned by Send) must keep the guard.
    // INDEF disables fill timeout, not reconciliation of an unrecorded send.
    if ($shortEntryElapsed < 2) { return; }
    if (IsObj($tsEntryTemplate)) { $tsEntryTemplate.Cancel(); }
    $tsProbeRef = $trade.Get("shortEntryProbeRef");
    $tsProbeCount = 0;
    while ($tsProbeCount < 200) {
        $tsProbeNext = $tsProbeRef + 1;
        $tsProbeOrder = GetOrderObj("Acc=" + $trade.account + ",Symb=" + $trade.symbol + ",RefNum>=" + $tsProbeNext);
        if (!IsObj($tsProbeOrder)) { break; }
        if ($tsProbeOrder.RefNum <= $tsProbeRef) {
            $trade.Set("shortEntryProbeRef", 0);
            $trade.Set("shortEntryProbeEmpty", 0);
            return;
        }
        if ($tsProbeOrder.Open > 0 && $tsProbeOrder.Side != "B") {
            $trade.Set("shortEntryProbeRef", 0);
            $trade.Set("shortEntryProbeEmpty", 0);
            return;
        }
        $tsProbeRef = $tsProbeOrder.RefNum;
        $tsProbeCount = $tsProbeCount + 1;
    }
    if ($tsProbeCount >= 200) {
        $trade.Set("shortEntryProbeRef", $tsProbeRef);
        // This pass is incomplete. Preserve the previous complete empty pass
        // so a long history can eventually satisfy the two-pass requirement.
        return;
    }
    $trade.Set("shortEntryProbeRef", 0);
    $tsEmptySecond = $trade.Get("shortEntryProbeEmpty");
    if ($tsEmptySecond == 0) {
        $trade.Set("shortEntryProbeEmpty", GetSecond() + 1);
        return;
    }
    $tsEmptyElapsed = GetSecond() - ($tsEmptySecond - 1);
    if ($tsEmptyElapsed < 0) { $tsEmptyElapsed = $tsEmptyElapsed + 86400; }
    if ($tsEmptyElapsed < 1) { return; }
    // Re-read signed position after the scan; a racing fill still needs stops.
    ExecHotkey("Read Position Only");
    if ($tradePositionValid != 1) { return; }
    $trade.shortEntryPending = 0;
    $trade.shortEntryOrder = 0;
    MsgLog("Short entry state reconciled for " + $trade.key + ": no recorded entry or working SELL after cancellation checks.");
}
if (IsObj($tsEntryOrder)) { $trade.shortEntryOrder = $tsEntryOrder; }
if (IsObj($tsEntryOrder) || $posNow < $trade.shortEntryPosBefore || $trade.shortEntryPending != 1) {
    $trade.Set("shortEntryProbeRef", 0);
    $trade.Set("shortEntryProbeEmpty", 0);
}
if ($posNow < $trade.shortEntryPosBefore) { $trade.shortEntryPending = 0; }
if ($trade.shortEntryPending == 1 && IsObj($tsEntryOrder)) {
    if ($tsEntryOrder.Open == 0 || $posNow < $trade.shortEntryPosBefore) {
        // Continue watching for later fills even after the first partial fill.
        $trade.shortEntryPending = 0;
    } else {
        $trade.shortEntryTicks = $trade.shortEntryTicks + 1;
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
