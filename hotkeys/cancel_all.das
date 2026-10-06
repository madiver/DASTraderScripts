// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// Group: Global controls & config
// Only selected account/symbol orders and alerts are canceled.
FocusWindow Primary_OE;
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
$tradeAccountObj.CancelOrder("BUY|SELL", $trade.symbol, 0);
$trade.entryPending = 0;
$trade.entryStage = 0;
$trade.entryWatch = 0;
ExecHotkey("Invalidate Trade Alerts");
$trade.stopArmed = 0;
Wait(100);
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow <= 0) { ExecHotkey("Clear Trade State"); ExecHotkey("End Trade Action"); return; }
if ($useAutoStop == "Yes" && $resetStopOnCancel == "Yes") {
    SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
    SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
    ExecHotkey("Set Auto Stop");
}

ExecHotkey("End Trade Action");
