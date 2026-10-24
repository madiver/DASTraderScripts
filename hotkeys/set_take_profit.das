// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// Group: Take profit
// RESET TAKE PROFIT: account-, direction- and generation-bound alert.
$tpCreated = 0;
$tpTimer = $timerMode;
$timerMode = 0;
$tpExpectedDirection = GetVar("TP_EXPECTED_DIRECTION") * 1;
SetVar("TP_EXPECTED_DIRECTION", 0);
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow == 0 || $avgNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$tpDirection = 1;
if ($posNow < 0) { $tpDirection = -1; }
if ($tpExpectedDirection != 0 && $tpDirection != $tpExpectedDirection) {
    ExecHotkey("End Trade Action");
    return;
}
if ($trade.exitPending == 1 && $tpTimer != 1) {
    ExecHotkey("End Trade Action");
    return;
}
$tpPx = $avgNow + ($stopLossTrigger * $takeProfitFactor * $tpDirection);
if ($stopLossTrigger <= 0 || $takeProfitFactor <= 0 || $tpPx <= 0) {
    if ($tpTimer != 1 || $trade.shortTpInvalidLogged != 1) {
        MsgLog("Take profit not created for " + $trade.key + ": target/risk must be positive. Review the stop distance and TP factor.");
    }
    $trade.shortTpInvalidLogged = 1;
    ExecHotkey("End Trade Action");
    return;
}
$inc = 0.01;
if ($tpPx < 1 || $avgNow < 1) { $inc = 0.001; }
if ($tpPx < 0.25 || $avgNow < 0.25) { $inc = 0.0005; }
$tpPx = Round($tpPx, 102, $inc);
if ($tpPx <= 0 || ($tpPx - $avgNow) * $tpDirection <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
if ($trade.tpName != "") {
    $toDel = GetAlertObj($trade.tpName);
    if (IsObj($toDel)) { $toDel.Delete(); }
}
$alertName = "TP " + $takeProfitFactor + "R Partial " + $trade.account + " " + $trade.symbol;
$al = NewAlertObj();
$al.Name = $alertName;
$al.Symb = $trade.symbol;
if ($tpDirection == 1) { $al.AddItem("Last Sale", ">", $tpPx); }
else { $al.AddItem("Last Sale", "<", $tpPx); }
$trade.tpRevision = $trade.tpRevision + 1;
$al.Script =
"SetVar(\"TP_ACCOUNT\",\"" + $trade.account + "\");" +
"SetVar(\"TP_SYMBOL\",\"" + $trade.symbol + "\");" +
"SetVar(\"TP_GENERATION\"," + $trade.generation + ");" +
"SetVar(\"TP_DIRECTION\"," + $tpDirection + ");" +
"SetVar(\"TP_REVISION\"," + $trade.tpRevision + ");" +
"ExecHotkey(\"Take Profit Executor\");";
$al.Speak = 0;
$al.PlaySound = 0;
$al.AutoDelete = 1;
$al.Loop = 0;
$al.PopupWindow = 0;
$al.Save();
$trade.active = 1;
$trade.tpName = $alertName;
$trade.tpDirection = $tpDirection;
$trade.deferredTp = 0;
$trade.tpCancelPending = 0;
$trade.shortTpInvalidLogged = 0;
if ($tpDirection == -1) {
    $trade.shortWatch = 1;
    $trade.shortTpQty = 0 - $posNow;
    $trade.shortTpAvg = $avgNow;
    $trade.shortTpDone = 0;
}
$tpCreated = 1;

ExecHotkey("End Trade Action");
