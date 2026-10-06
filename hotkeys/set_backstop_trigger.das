// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// Group: Stops
// Arm a LONG backstop for the exact account and symbol owning the recorded stop.
$timerMode = 0;
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow <= 0 || $trade.lastStop <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$trade.backstopStop = $trade.lastStop;
$trade.backstopRetries = $backstopMaxRetries;
$trade.backstopArmed = 1;
$trade.active = 1;
ExecHotkey("Build Backstop Alert");

ExecHotkey("End Trade Action");
