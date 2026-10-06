// Group: Global controls & config
// Emergency exit: exact account/symbol, full signed position, $0.50 offset.
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
$gtfoExecPrice = $tradeBid - 0.50;
if ($posNow < 0) {
    $gtfoExecSide = "B";
    $gtfoExecQty = 0 - $posNow;
    $gtfoExecPrice = $tradeAsk + 0.50;
}
if (($posNow > 0 && $tradeBid <= 0) || ($posNow < 0 && $tradeAsk <= 0)) {
    $gtfoExecPrice = $tradeLast - 0.50;
    if ($posNow < 0) { $gtfoExecPrice = $tradeLast + 0.50; }
    if ($tradeLast <= 0) { $gtfoExecPrice = 0; }
}
if ($gtfoExecPrice <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
// Arithmetic snapping works without editing the currently selected montage.
$gtfoExecInc = 0.01;
if ($gtfoExecPrice < 1) { $gtfoExecInc = 0.001; }
if ($gtfoExecPrice < 0.25) { $gtfoExecInc = 0.0001; }
$gtfoExecTicks = ($gtfoExecPrice / $gtfoExecInc) + 0.5;
$gtfoExecTicks = $gtfoExecTicks - ($gtfoExecTicks % 1);
$gtfoExecPrice = $gtfoExecTicks * $gtfoExecInc;
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
