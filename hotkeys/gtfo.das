// Group: Global controls & config
// Emergency exit: full signed position, $0.50 cushion capped by quote percentage.
// Preserve a panic request arriving during another action's cancel/fill wait.
if (GetVar("tradeActionDepth") * 1 > 0) {
    $gtfoQueueMontage = GetWindowObj("Primary_OE");
    if (IsObj($gtfoQueueMontage)) {
        SetVar("GTFO_PENDING_ACCOUNT", $gtfoQueueMontage.Account);
        SetVar("GTFO_PENDING_SYMBOL", $gtfoQueueMontage.Symb);
        MsgLog("GTFO queued for " + $gtfoQueueMontage.Account + " " + $gtfoQueueMontage.Symb + "; current action is finishing.");
    }
    return;
}
$tradeActionDepth = 1;
$tradeActionUntil = GetSecond() + 30;
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1 || $posNow == 0) {
    ExecHotkey("End Trade Action");
    return;
}
$gtfoDirection = 1;
if ($posNow < 0) { $gtfoDirection = -1; }
$gtfoExecRoute = $gtfoRoute;
if ($gtfoExecRoute == "") { $gtfoExecRoute = $orderRoute; }
// Resolve AUTOL immediately before this submission; manual routes pass through.
$routeRequest = $gtfoExecRoute;
$routeSide = "S";
$routeLimit = 0;
$routeBid = 0;
$routeAsk = 0;
$routeUrgent = 1;
ExecHotkey("Resolve Order Route");
if ($resolvedOrderRoute == "") {
    ExecHotkey("End Trade Action");
    return;
}
$gtfoExecRoute = $resolvedOrderRoute;
if ($gtfoExecRoute == "") {
    ExecHotkey("End Trade Action");
    return;
}
$tradeAccountObj.CancelOrder("BUY|SELL", $trade.symbol, 0);
ExecHotkey("Invalidate Trade Alerts");
Wait(100);
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1 || $posNow == 0 || $posNow * $gtfoDirection <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$gtfoExecSide = "S";
$gtfoExecQty = $posNow;
$gtfoRefPrice = $tradeBid;
if ($posNow < 0) {
    $gtfoExecSide = "B";
    $gtfoExecQty = 0 - $posNow;
    $gtfoRefPrice = $tradeAsk;
}
if ($gtfoRefPrice <= 0) { $gtfoRefPrice = $tradeLast; }
if ($gtfoRefPrice <= 0) {
    MsgLog("GTFO aborted: no positive quote/last price for " + $trade.key + ".");
    ExecHotkey("End Trade Action");
    return;
}
$gtfoCushion = 0.50;
$gtfoCushionCap = $gtfoRefPrice * $gtfoOffsetMaxPct;
if ($gtfoOffsetMaxPct > 0 && $gtfoCushion > $gtfoCushionCap) { $gtfoCushion = $gtfoCushionCap; }
$gtfoExecPrice = $gtfoRefPrice - $gtfoCushion;
if ($posNow < 0) { $gtfoExecPrice = $gtfoRefPrice + $gtfoCushion; }
// Arithmetic snapping works without editing the currently selected montage.
$gtfoExecInc = 0.01;
if ($gtfoExecPrice < 1) { $gtfoExecInc = 0.001; }
if ($gtfoExecPrice < 0.25) { $gtfoExecInc = 0.0001; }
$gtfoExecTicks = ($gtfoExecPrice / $gtfoExecInc) + 0.5;
$gtfoExecTicks = $gtfoExecTicks - ($gtfoExecTicks % 1);
$gtfoExecPrice = $gtfoExecTicks * $gtfoExecInc;
// Keep rounding inside the cap: raise a sell limit or lower a buy limit one tick.
if ($gtfoOffsetMaxPct > 0) {
    if ($posNow > 0 && $gtfoExecPrice < $gtfoRefPrice - $gtfoCushionCap) {
        $gtfoExecPrice = ($gtfoExecTicks + 1) * $gtfoExecInc;
    }
    if ($posNow < 0 && $gtfoExecPrice > $gtfoRefPrice + $gtfoCushionCap) {
        $gtfoExecPrice = ($gtfoExecTicks - 1) * $gtfoExecInc;
    }
}
// A disabled/oversized percentage cap must never produce a nonpositive sell.
if ($gtfoExecPrice < $gtfoExecInc) { $gtfoExecPrice = $gtfoExecInc; }
if ($posNow < 0 && $gtfoOffsetMaxPct > 0 && $gtfoExecPrice > $gtfoRefPrice + $gtfoCushionCap) {
    MsgLog("GTFO aborted: no positive buy limit at supported precision inside the configured cap.");
    ExecHotkey("End Trade Action");
    return;
}
$gtfoExecOrder = NewOrderObj();
$gtfoExecOrder.Account = $trade.account;
$gtfoExecOrder.Symbol = $trade.symbol;
$gtfoExecOrder.Route = $gtfoExecRoute;
$gtfoExecOrder.Type = "L";
$gtfoExecOrder.Tif = "DAY+";
$gtfoExecOrder.Side = $gtfoExecSide;
$gtfoExecOrder.Price = $gtfoExecPrice;
$gtfoExecOrder.Share = $gtfoExecQty;
$gtfoExecOrder.Send();
MsgLog("GTFO submitted for " + $trade.key + " via " + $gtfoExecRoute + ".");
ExecHotkey("End Trade Action");
