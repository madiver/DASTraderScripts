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
$trade.stopArmed = 0;
$tradeAccountObj.CancelOrder("SELL", $trade.symbol, 0);
Wait(200);
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1 || $posNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$refPx = $tradeBid;
if ($refPx <= 0) { $refPx = $tradeLast; }
if ($refPx <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$inc = 0.01;
if ($refPx < 1) { $inc = 0.001; }
if ($refPx < 0.25) { $inc = 0.0005; }
$px = Round($refPx - $backstopBidOffset, 102, $inc);
if ($px < $inc) { $px = $inc; }
$route = $gtfoRoute;
if ($route == "") { $route = $orderRoute; }
if ($route == "") {
    ExecHotkey("End Trade Action");
    return;
}
$o = NewOrderObj();
$o.Account = $trade.account;
$o.Symbol = $trade.symbol;
$o.Route = $route;
$o.Tif = "DAY+";
$o.Side = "S";
$o.Type = "L";
$o.Price = $px;
$o.Share = $posNow;
$o.Send();
Wait(300);
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow <= 0) { ExecHotkey("Clear Trade State"); ExecHotkey("End Trade Action"); return; }
if ($trade.backstopRetries > 0) {
    ExecHotkey("Build Backstop Alert");
} else {
    $trade.backstopArmed = 0;
    MsgLog("Backstop retries exhausted: " + $trade.key + ".");
}

ExecHotkey("End Trade Action");
