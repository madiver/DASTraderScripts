// Group: Utilities & toggles
// Process one explicitly bound trade. The outer timer visits every active context.
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) { return; }
if ($posNow < 0) {
    // A former long was reversed manually: never arm a SELL against the short.
    if ($trade.entryPending == 1) { $tradeAccountObj.CancelOrder("BUY", $mySym, 0); }
    ExecHotkey("Clear Trade State");
    return;
}
if ($trade.entryPending != 1) {
    if ($posNow == 0) { ExecHotkey("Clear Trade State"); return; }
    if ($trade.entryWatch != 1) { return; }
    if ($posNow > $trade.entryLastPos) {
        $trade.entryStage = 1;
        $trade.entryPending = 1;
        $trade.entryTicks = 0;
    } else { return; }
}
if ($trade.entryStage == 0) {
    $trade.entryTicks = $trade.entryTicks + 1;
    if ($posNow > $trade.entryPosBefore) {
        $trade.entryStage = 1;
        $trade.entryTicks = 0;
    } else {
        if ($entryMaxTicks > 0 && $trade.entryTicks >= $entryMaxTicks) {
            $tradeAccountObj.CancelOrder("BUY", $mySym, 0);
            $trade.entryPending = 0;
            $trade.entryStage = 0;
            // Watch any existing long for a late fill after cancellation.
            $trade.entryWatch = 1;
            $trade.entryLastPos = $posNow;
            if ($posNow == 0) { ExecHotkey("Clear Trade State"); }
        }
        return;
    }
}
if ($posNow <= 0) {
    $trade.entryPending = 0;
    ExecHotkey("Clear Trade State");
    return;
}
if ($trade.entryStage == 1) {
    if ($useAutoStop == "Yes") {
        $trade.stopArmed = 0;
        $tradeAccountObj.CancelOrder("SELL", $mySym, 0);
    }
    $trade.entryStage = 2;
    return;
}
if ($trade.entryStage == 2) {
    if ($useAutoStop == "Yes") {
        $timerMode = 1;
        if ($trade.entryScaleIn == 1) {
            SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
            SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
            ExecHotkey("Set Auto Stop BE Scale 1/1");
        } else {
            SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
            SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
            ExecHotkey("Set Auto Stop");
        }
        // Retry when position/average data is unavailable. Do not silently
        // mark an unprotected trade as armed.
        if ($stopSubmitted != 1) { return; }
    }
    $trade.entryStage = 3;
    return;
}
if ($trade.entryStage == 3) {
    if ($useTakeProfit == "Yes") {
        $doTp = 0;
        if ($trade.entryPosBefore <= 0 || $trade.entryAvgBefore <= 0 || $tradeBid <= $trade.entryAvgBefore) { $doTp = 1; }
        if ($doTp == 1) {
            $timerMode = 1;
            SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
            SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
            ExecHotkey("Set Take Profit");
            if ($tpCreated != 1) { return; }
        }
    }
    $trade.entryPending = 0;
    $trade.entryStage = 0;
    $trade.entryTicks = 0;
    $trade.entryWatch = 1;
    $trade.entryLastPos = $posNow;
}
