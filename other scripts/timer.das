// Ignore: True
// Account/symbol-scoped entry protection and alert cleanup.
// Wait-bearing scripts hold a short lease on shared DAS scratch variables.
if (GetVar("tradeActionDepth") * 1 > 0) {
    $timerNow = GetSecond();
    if ($timerNow < $tradeActionUntil && $timerNow >= $tradeActionUntil - 30) { return; }
    // Recover a script interrupted by a DAS error, including midnight rollover.
    $tradeActionDepth = 0;
    ExecHotkey("End Trade Action");
}
ExecHotkey("Hijack Exit");
if (!IsObj(GetVar("tradeSlots"))) { return; }
$timerTradeIndex = 0;
while ($timerTradeIndex < $tradeSlotCount) {
    $timerTrade = $tradeSlots.Get($timerTradeIndex);
    if (IsObj($timerTrade)) {
        if ($timerTrade.active == 1 || $timerTrade.entryPending == 1) {
            SetVar("TRADE_CONTEXT_ACCOUNT", $timerTrade.account);
            SetVar("TRADE_CONTEXT_SYMBOL", $timerTrade.symbol);
            ExecHotkey("Timer Entry Handler");
            if ($timerTrade.deferredTp == 1) {
                $timerTrade.deferredTp = 0;
                SetVar("TP_ACCOUNT", $timerTrade.account);
                SetVar("TP_SYMBOL", $timerTrade.symbol);
                SetVar("TP_GENERATION", $timerTrade.generation);
                ExecHotkey("Take Profit Executor");
            }
            if ($timerTrade.deferredBackstop == 1) {
                $timerTrade.deferredBackstop = 0;
                SetVar("BACKSTOP_ACCOUNT", $timerTrade.account);
                SetVar("BACKSTOP_SYMBOL", $timerTrade.symbol);
                SetVar("BACKSTOP_GENERATION", $timerTrade.generation);
                ExecHotkey("Backstop Exit Executor");
            }
        }
    }
    $timerTradeIndex = $timerTradeIndex + 1;
}
