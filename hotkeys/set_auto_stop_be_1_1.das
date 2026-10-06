// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// Group: Stops
// LONG ONLY. Account/symbol context is independent of the selected montage.
$stopSubmitted = 0;
$stopTimer = $timerMode;
$timerMode = 0;
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
// Validate price inputs before removing existing protection.
if ($avgNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
if ($stopTimer != 1) {
    $trade.stopArmed = 0;
    $tradeAccountObj.CancelOrder("SELL", $trade.symbol, 0);
    Wait(350);
}
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1 || $posNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
if ($avgNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$inc = 0.01;
if ($avgNow < 1) { $inc = 0.001; }
if ($avgNow < 0.25) { $inc = 0.0005; }
$avgSnap = Round($avgNow, 102, $inc);
$stop = $avgSnap - $stopLossTrigger;
$px = $stop - $exitOffset;
$stopType = "SLP";
$stopRoute = "STOP";
if ($tradeBid <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$stop = Round($avgSnap + 0.03, 102, $inc);
$px = $avgSnap;
if ($tradeBid < $stop) {
    $stop = $avgSnap;
    $stopType = "L";
    $stopRoute = $orderRoute;
    $px = Round($avgSnap, 102, 0.01);
    if ($pegToBid == 1 && $tradeBid > $px) { $px = Round($tradeBid, 102, 0.01); }
}
$stop = Round($stop, 102, $inc);
$px = Round($px, 102, $inc);
if ($stopType == "SLP" && $px >= $stop) { $px = Round($stop - $inc, 102, $inc); }
if ($stop <= 0 || $px <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$qtyProtect = $posNow / 1;
$qtyProtect = $qtyProtect - ($qtyProtect % 1);
if ($qtyProtect < 1) { $qtyProtect = 1; }
if ($qtyProtect > $posNow) { $qtyProtect = $posNow; }
$s = NewOrderObj();
$s.Account = $trade.account;
$s.Symbol = $trade.symbol;
$s.Route = $stopRoute;
$s.Tif = "DAY+";
$s.Side = "S";
$s.Type = $stopType;
if ($stopType == "SLP") { $s.StopPrice = $stop; }
$s.Price = $px;
$s.Share = $qtyProtect;
$s.Send();
$trade.active = 1;
$trade.lastStop = $stop;
$trade.stopArmed = 1;
$stopSubmitted = 1;

ExecHotkey("End Trade Action");
