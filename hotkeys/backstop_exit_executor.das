// Alerts arriving during a cancel/fill wait are queued on their own trade.
if (GetVar("tradeActionDepth") * 1 > 0) {
    $deferAcc = GetVar("BACKSTOP_ACCOUNT");
    $deferSym = GetVar("BACKSTOP_SYMBOL");
    $deferGen = GetVar("BACKSTOP_GENERATION") * 1;
    if (IsObj(GetVar("tradeStates"))) {
        $deferTrade = $tradeStates.Get($deferAcc + "|" + $deferSym);
        if (IsObj($deferTrade)) {
            if ($deferTrade.active == 1 && $deferTrade.generation == $deferGen) {
                $deferTrade.deferredBackstop = 1;
            }
        }
    }
    SetVar("BACKSTOP_ACCOUNT", "");
    SetVar("BACKSTOP_SYMBOL", "");
    SetVar("BACKSTOP_GENERATION", "");
    return;
}
$tradeActionDepth = 1;
$tradeActionUntil = GetSecond() + 30;
// Group: Stops
// LONG ONLY. Account/symbol and retry budget come from this trade's alert.
$execAccount = StrTrim("" + GetVar("BACKSTOP_ACCOUNT"));
$execSymbol = StrTrim("" + GetVar("BACKSTOP_SYMBOL"));
$execGeneration = GetVar("BACKSTOP_GENERATION") * 1;
SetVar("BACKSTOP_ACCOUNT", "");
SetVar("BACKSTOP_SYMBOL", "");
SetVar("BACKSTOP_GENERATION", "");
if ($execAccount == "" || $execSymbol == "" || $execGeneration <= 0) {
    MsgLog("Alert ignored: missing account/symbol/trade generation. Recreate legacy alerts.");
    ExecHotkey("End Trade Action");
    return;
}
SetVar("TRADE_CONTEXT_ACCOUNT", $execAccount);
SetVar("TRADE_CONTEXT_SYMBOL", $execSymbol);
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($trade.generation != $execGeneration || $trade.active != 1 || $posNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
if ($trade.backstopArmed != 1 || $trade.backstopRetries <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$trade.backstopRetries = $trade.backstopRetries - 1;
SetVar("EXIT_REQUEST_ACCOUNT", $trade.account);
SetVar("EXIT_REQUEST_SYMBOL", $trade.symbol);
SetVar("EXIT_REQUEST_GENERATION", $execGeneration);
SetVar("EXIT_REQUEST_KIND", "BACKSTOP");
SetVar("EXIT_REQUEST_DIRECTION", 1);
SetVar("EXIT_REQUEST_FRACTION", 1);
SetVar("EXIT_REQUEST_PRIORITY", 40);
ExecHotkey("Request Exit");
ExecHotkey("End Trade Action");
