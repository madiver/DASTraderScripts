// Group: Utilities & toggles
// Drain only after the current action releases its scratch-variable lease.
if (GetVar("tradeActionDepth") * 1 > 0 || GetVar("exitDraining") * 1 == 1) { return; }
if (!IsObj(GetVar("exitRequests")) || !IsObj(GetVar("exitRequestKeys"))) { return; }
$exitDraining = 1;
$edPass = 0;
while ($edPass < 2) {
    $edIndex = 0;
    while ($edIndex < $exitRequestCount) {
        $edKey = $exitRequestKeys.Get($edIndex);
        $edRequest = $exitRequests.Get($edKey);
        if (IsObj($edRequest)) {
            $tradeActionDepth = 1;
            $tradeActionUntil = GetSecond() + 30;
            SetVar("TRADE_CONTEXT_ACCOUNT", $edRequest.account);
            SetVar("TRADE_CONTEXT_SYMBOL", $edRequest.symbol);
            ExecHotkey("Load Trade Context");
            if ($tradeContextValid == 1) { ExecHotkey("Process Exit"); }
            ExecHotkey("End Trade Action");
        }
        if (!IsObj($exitRequests.Get($edKey))) { $exitRequestKeys.Set($edIndex, ""); }
        $edIndex = $edIndex + 1;
    }
    $edPass = $edPass + 1;
}
$exitDraining = 0;
