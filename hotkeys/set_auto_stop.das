// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// Group: Stops
// RESET STOP LOSS: sell-stop a long or buy-stop a short using signed size.
// Account/symbol context is independent of the selected montage.
$stopSubmitted = 0;
$stopTimer = $timerMode;
$timerMode = 0;
$stopShortTimer = GetVar("SHORT_STOP_TIMER") * 1;
SetVar("SHORT_STOP_TIMER", 0);
$stopShortBE = GetVar("SHORT_STOP_BE") * 1;
SetVar("SHORT_STOP_BE", 0);
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow == 0) {
    ExecHotkey("End Trade Action");
    return;
}
if ($stopShortTimer == 1 && $posNow > 0) {
    ExecHotkey("End Trade Action");
    return;
}
if (($trade.exitPending == 1 || $trade.tpCancelPending == 1) && $stopTimer != 1) {
    MsgLog("Exit still pending; protection is managed by the timer.");
    ExecHotkey("End Trade Action");
    return;
}
// Validate price inputs before removing existing protection.
if ($avgNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$stopDirection = 1;
$stopCancelSide = "SELL";
if ($posNow < 0) {
    // Only the short handler may arm a short from timer mode.
    if (($stopTimer == 1 && $stopShortTimer != 1) || $stopLossTrigger <= 0) {
        ExecHotkey("End Trade Action");
        return;
    }
    $stopDirection = -1;
    $stopCancelSide = "BUY";
}
$stopOldShortOrder = $trade.Get("shortStopOrder");
if ($stopTimer != 1) {
    if ($stopDirection == -1 && $trade.shortWatch != 1) {
        // Discard any former long's alerts/staging before tracking a short stop.
        $stopShortEntryOrder = $trade.shortEntryOrder;
        $stopShortEntryPending = $trade.shortEntryPending;
        $stopShortEntryTicks = $trade.shortEntryTicks;
        $stopShortEntryPosBefore = $trade.shortEntryPosBefore;
        $stopShortCoverPending = $trade.shortCoverPending;
        $stopShortBuyScanRef = $trade.shortBuyScanRef;
        ExecHotkey("Invalidate Trade Alerts");
        // RESET must retain an unfilled short remainder for late-fill cleanup.
        $trade.shortEntryOrder = $stopShortEntryOrder;
        $trade.shortEntryPending = $stopShortEntryPending;
        $trade.shortEntryTicks = $stopShortEntryTicks;
        $trade.shortEntryPosBefore = $stopShortEntryPosBefore;
        $trade.shortCoverPending = $stopShortCoverPending;
        $trade.shortBuyScanRef = $stopShortBuyScanRef;
    }
    $trade.stopArmed = 0;
    $tradeAccountObj.CancelOrder($stopCancelSide, $trade.symbol, 0);
    // Also remove a retained short stop if this position has become long.
    if (IsObj($stopOldShortOrder) && $stopDirection == 1) { $stopOldShortOrder.Cancel(); }
    Wait(350);
}
ExecHotkey("Read Trade Position");
if (IsObj($stopOldShortOrder)) {
    $stopOldShortOrder.GetInfo();
    if ($stopOldShortOrder.Open != 0) {
        $trade.Set("shortStopOrder", $stopOldShortOrder);
        $trade.active = 1;
        $trade.shortWatch = 1;
        MsgLog("RESET STOP LOSS: previous short-stop cancellation pending for " + $trade.key + "; no overlapping stop submitted.");
        ExecHotkey("End Trade Action");
        return;
    }
    $trade.Set("shortStopOrder", 0);
}
if ($tradePositionValid != 1 || $posNow * $stopDirection <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
if ($avgNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
if ($stopDirection == -1 && $stopTimer != 1) {
    ExecHotkey("Check Working Buys");
    if ($workingBuys != 0) {
        $trade.shortWatch = 1;
        $trade.active = 1;
        MsgLog("RESET STOP LOSS: waiting for BUY cancellations/order history for " + $trade.key + "; no overlapping stop submitted.");
        ExecHotkey("End Trade Action");
        return;
    }
}
$inc = 0.01;
if ($avgNow < 1) { $inc = 0.001; }
if ($avgNow < 0.25) { $inc = 0.0005; }
$avgSnap = Round($avgNow, 102, $inc);
$stop = $avgSnap - $stopLossTrigger * $stopDirection;
$px = $stop - $exitOffset * $stopDirection;
$stopType = "SLP";
$stopRoute = "STOP";
$stop = Round($stop, 102, $inc);
$px = Round($px, 102, $inc);
if ($stopDirection == 1 && $stopType == "SLP" && $px >= $stop) { $px = Round($stop - $inc, 102, $inc); }
if ($stopDirection == -1) {
    // Short prices can cross the $0.25/$1 precision bands above average cost.
    $inc = 0.01;
    if ($stop < 1) { $inc = 0.001; }
    if ($stop < 0.25) { $inc = 0.0005; }
    $stop = Round($stop, 102, $inc);
    $px = $stop + $exitOffset;
    $inc = 0.01;
    if ($px < 1) { $inc = 0.001; }
    if ($px < 0.25) { $inc = 0.0005; }
    $px = Round($px, 102, $inc);
    if ($px <= $stop) { $px = Round($stop + $inc, 102, $inc); }
    if ($stopShortBE == 1) {
        if ($tradeAsk <= 0) { ExecHotkey("End Trade Action"); return; }
        // Mirror the long BE stop: trigger three cents before average cost.
        $stop = $avgSnap - 0.03;
        $px = $avgSnap;
        if ($tradeAsk > $stop) {
            $stop = $avgSnap;
            $stopType = "L";
            $stopRoute = $orderRoute;
            if ($pegToBid == 1 && $tradeAsk < $px) { $px = $tradeAsk; }
        }
        $inc = 0.01;
        if ($stop < 1) { $inc = 0.001; }
        if ($stop < 0.25) { $inc = 0.0005; }
        $stop = Round($stop, 102, $inc);
        $inc = 0.01;
        if ($px < 1) { $inc = 0.001; }
        if ($px < 0.25) { $inc = 0.0005; }
        $px = Round($px, 102, $inc);
        if ($stopType == "SLP" && $px <= $stop) { $px = Round($stop + $inc, 102, $inc); }
    }
}
if ($stop <= 0 || $px <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$stopPositionSize = $posNow * $stopDirection;
$qtyProtect = $stopPositionSize / 1;
$qtyProtect = $qtyProtect - ($qtyProtect % 1);
if ($qtyProtect < 1) { $qtyProtect = 1; }
if ($qtyProtect > $stopPositionSize) { $qtyProtect = $stopPositionSize; }
if ($stopDirection == -1 && $stopType == "L") {
    $routeRequest = $stopRoute;
    $routeSide = "B";
    $routeLimit = $px;
    $routeBid = $tradeBid;
    $routeAsk = $tradeAsk;
    $routeUrgent = 0;
    ExecHotkey("Resolve Order Route");
    if ($resolvedOrderRoute == "") { ExecHotkey("End Trade Action"); return; }
    $stopRoute = $resolvedOrderRoute;
}
$s = NewOrderObj();
$s.Account = $trade.account;
$s.Symbol = $trade.symbol;
$s.Route = $stopRoute;
$s.Tif = "DAY+";
$s.Side = "S";
if ($stopDirection == -1) { $s.Side = "B"; }
$s.Type = $stopType;
if ($stopType == "SLP") { $s.StopPrice = $stop; }
$s.Price = $px;
$s.Share = $qtyProtect;
$s.Send();
$trade.active = 1;
$trade.lastStop = $stop;
$trade.stopArmed = 1;
if ($stopDirection == -1) {
    $trade.Set("shortStopOrder", $s);
    $trade.shortWatch = 1;
    $trade.shortStopQty = $qtyProtect;
    $trade.shortStopAvg = $avgNow;
    $trade.shortStopBE = $stopShortBE;
    MsgLog("RESET STOP LOSS: short " + $trade.key + ", buy-stop " + $qtyProtect + " at " + $stop + ", limit " + $px + ".");
}
$stopSubmitted = 1;

ExecHotkey("End Trade Action");
