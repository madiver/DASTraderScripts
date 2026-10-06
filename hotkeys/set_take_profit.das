// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// Group: Take profit
// Account-bound, generation-bound LONG take-profit alert. Never changes UI focus.
$tpCreated = 0;
$timerMode = 0;
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow <= 0 || $avgNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$tpPx = $avgNow + ($stopLossTrigger * $takeProfitFactor);
$inc = 0.01;
if ($tpPx < 1 || $avgNow < 1) { $inc = 0.001; }
if ($tpPx < 0.25 || $avgNow < 0.25) { $inc = 0.0005; }
$tpPx = Round($tpPx, 102, $inc);
if ($trade.tpName != "") {
    $toDel = GetAlertObj($trade.tpName);
    if (IsObj($toDel)) { $toDel.Delete(); }
}
$alertName = "TP " + $takeProfitFactor + "R Partial " + $trade.account + " " + $trade.symbol;
$al = NewAlertObj();
$al.Name = $alertName;
$al.Symb = $trade.symbol;
$al.AddItem("Last Sale", ">", $tpPx);
$al.Script =
"SetVar(\"TP_ACCOUNT\",\"" + $trade.account + "\");" +
"SetVar(\"TP_SYMBOL\",\"" + $trade.symbol + "\");" +
"SetVar(\"TP_GENERATION\"," + $trade.generation + ");" +
"ExecHotkey(\"Take Profit Executor\");";
$al.Speak = 0;
$al.PlaySound = 0;
$al.AutoDelete = 1;
$al.Loop = 0;
$al.PopupWindow = 0;
$al.Save();
$trade.active = 1;
$trade.tpName = $alertName;
$tpCreated = 1;

ExecHotkey("End Trade Action");
