// Group: Utilities & toggles
// Internal: monitor one account/symbol's partial exit. Never waits or changes UI.
ExecHotkey("Load Position Context");
if ($tradeContextValid != 1 || $trade.exitPending != 1) { return; }
if ($trade.exitGeneration != $trade.generation) { return; }
if (!IsObj($trade.exitOrder)) { return; }
$teDirection = 1;
if ($trade.exitStartPos < 0) { $teDirection = -1; }
$teStartSize = $trade.exitStartPos * $teDirection;
// Refresh order status even when position data is temporarily unavailable.
$trade.exitOrder.GetInfo();
if ($tradePositionValid == 1 && $teDirection == -1 && $posNow >= 0) {
    // A flat/reversed short cannot retain an unfilled entry or BUY protection.
    $teShortEntry = $trade.shortEntryOrder;
    if (IsObj($teShortEntry)) {
        $teShortEntry.GetInfo();
        if ($teShortEntry.Open != 0) { $teShortEntry.Cancel(); return; }
    }
    $teShortStop = $trade.Get("shortStopOrder");
    if (IsObj($teShortStop)) {
        $teShortStop.GetInfo();
        if ($teShortStop.Open != 0) { $teShortStop.Cancel(); return; }
    }
}
$teElapsed = GetSecond() - $trade.exitStarted;
if ($teElapsed < 0) { $teElapsed = $teElapsed + 86400; }
if ($trade.exitStage == 5) {
    // Retain identity until the next fresh tick confirms short-order cleanup.
    if ($tradePositionValid != 1) { return; }
    if ($posNow * $teDirection > 0) { $trade.exitStage = 2; }
    else {
        if ($posNow <= 0) { ExecHotkey("Clear Trade State"); }
        else { ExecHotkey("Invalidate Trade Alerts"); $trade.active = 0; }
        return;
    }
}
if ($trade.exitStage == 1) {
    $teFinished = 0;
    if ($tradePositionValid == 1) {
        if ($posNow * $teDirection <= $teStartSize - $trade.exitQty) { $teFinished = 1; }
    }
    if ($trade.exitOrder.Open == 0 || $teElapsed >= $trade.exitTimeout) { $teFinished = 1; }
    if ($teFinished != 1) { return; }
    // Open=0 can be rejection/cancel: actual position delta decides TP success.
    $trade.exitOrder.Cancel();
    $trade.exitStage = 2;
    $trade.exitOrder.GetInfo();
}
if ($trade.exitStage == 2) {
    // Do not overlap protection with an unacknowledged residual exit.
    if ($trade.exitOrder.Open != 0) {
        $trade.exitOrder.Cancel();
        if ($teElapsed >= 30 && $trade.exitCancelWarned != 1) {
            MsgLog("Exit cancellation still pending for " + $trade.key + "; protection waits for confirmation. Use GTFO if needed.");
            $trade.exitCancelWarned = 1;
        }
        return;
    }
    // Cancellation may include a final fill; refresh the signed size before
    // classifying TP success or deciding that this trade is flat.
    ExecHotkey("Read Position Only");
    if ($tradePositionValid != 1) { return; }
    if ($posNow * $teDirection <= 0) {
        if ($teDirection == -1) { $trade.exitStage = 5; }
        else { ExecHotkey("Clear Trade State"); }
        return;
    }
    $trade.exitFullFill = 0;
    if ($posNow * $teDirection <= $teStartSize - $trade.exitQty) { $trade.exitFullFill = 1; }
    $trade.exitStage = 3;
}
if ($trade.exitStage == 3) {
    if ($tradePositionValid != 1) { return; }
    if ($posNow * $teDirection <= 0) {
        if ($teDirection == -1) { $trade.exitStage = 5; }
        else { ExecHotkey("Clear Trade State"); }
        return;
    }
    if ($useAutoStop == "Yes") {
        if ($teDirection == -1) {
            ExecHotkey("Check Working Buys");
            if ($workingBuys != 0) { return; }
            SetVar("SHORT_STOP_TIMER", 1);
        }
        $timerMode = 1;
        SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
        SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
        if ($trade.exitIsTp == 1 && $trade.exitFullFill == 1) {
            ExecHotkey("Set Auto Stop BE 1/1");
        } else { ExecHotkey("Set Auto Stop"); }
        if ($stopSubmitted != 1) { return; }
    }
    // Keep the quantity actually protected; a later fill must remain visible
    // to entryWatch rather than being hidden by a newer position snapshot.
    $trade.entryLastPos = $posNow;
    $trade.exitStage = 4;
}
if ($trade.exitStage == 4) {
    // TP builder may retry if average data is missing; never duplicate the stop.
    if ($useTakeProfit == "Yes" && ($trade.exitIsTp != 1 || $trade.exitFullFill != 1)) {
        $timerMode = 1;
        SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
        SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
        SetVar("TP_EXPECTED_DIRECTION", $teDirection);
        ExecHotkey("Set Take Profit");
        if ($tpCreated != 1) { return; }
    }
    ExecHotkey("Read Position Only");
    if ($tradePositionValid != 1) { return; }
    if ($posNow * $teDirection <= 0) {
        if ($teDirection == -1) { $trade.exitStage = 5; }
        else { ExecHotkey("Clear Trade State"); }
        return;
    }
    if ($teDirection == -1) {
        $trade.shortWatch = 1;
        $trade.shortCoverPending = 0;
        $trade.shortTpQty = 0 - $posNow;
        $trade.shortTpAvg = $avgNow;
        if ($trade.exitIsTp == 1 && $trade.exitFullFill == 1) {
            $trade.shortTpDone = 1;
            $trade.tpName = "";
        }
    } else { $trade.entryWatch = 1; }
    $trade.exitPending = 0;
    $trade.exitStage = 0;
    $trade.exitOrder = 0;
}
