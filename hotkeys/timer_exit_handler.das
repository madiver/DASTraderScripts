// Group: Utilities & toggles
// Process one explicitly bound exit. Slow acknowledgment checks never wait here.
ExecHotkey("Load Position Context");
if ($tradeContextValid != 1) { return; }
if ($trade.exitPending != 1) { return; }
if ($trade.closeManaged != 1) {
    if ($trade.Get("legacyExitWarned") != 1) {
        MsgLog("Exit has no usable tracking state for " + $trade.key + "; use Cancel All to reconcile orders.");
        $trade.Set("legacyExitWarned", 1);
    }
    return;
}
$tradeActionDepth = 1;
$tradeActionUntil = GetSecond() + 30;
SetVar("EXIT_FROM_TIMER", 1);
ExecHotkey("Process Exit");
ExecHotkey("End Trade Action");
