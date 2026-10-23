// Alerts arriving during a cancel/fill wait are queued on their own trade.
if (GetVar("tradeActionDepth") * 1 > 0) {
    $deferAcc = GetVar("TP_ACCOUNT");
    $deferSym = GetVar("TP_SYMBOL");
    $deferGen = GetVar("TP_GENERATION") * 1;
    if (IsObj(GetVar("tradeStates"))) {
        $deferTrade = $tradeStates.Get($deferAcc + "|" + $deferSym);
        if (IsObj($deferTrade)) {
            if ($deferTrade.active == 1 && $deferTrade.generation == $deferGen) {
                $deferTrade.deferredTp = 1;
            }
        }
    }
    SetVar("TP_ACCOUNT", "");
    SetVar("TP_SYMBOL", "");
    SetVar("TP_GENERATION", "");
    return;
}
$tradeActionDepth = 1;
$tradeActionUntil = GetSecond() + 30;
// Group: Take profit
// LONG ONLY. Alert payload supplies the account and symbol, never the active montage.
$execAccount = StrTrim("" + GetVar("TP_ACCOUNT"));
$execSymbol = StrTrim("" + GetVar("TP_SYMBOL"));
$execGeneration = GetVar("TP_GENERATION") * 1;
SetVar("TP_ACCOUNT", "");
SetVar("TP_SYMBOL", "");
SetVar("TP_GENERATION", "");
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
if ($trade.exitPending == 1) { ExecHotkey("End Trade Action"); return; }
$trade.stopArmed = 0;
$tradeAccountObj.CancelOrder("SELL", $trade.symbol, 0);
Wait(300);
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1 || $posNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$tpSize = $takeProfitSize;
$isLive = 0;
if (StrLen($myAcc) > 0 && StrFind($myAcc, "TR") != 0) { $isLive = 1; }
if ($rehab == 1 && ($isLive == 1 || $applyLiveGuardsToSim == 1)) { $tpSize = $takeProfitSizeRehab; }
$takeQty = $posNow * $tpSize;
$takeQty = $takeQty - ($takeQty % 1);
if ($takeQty < 1) { $takeQty = 1; }
if ($takeQty > $posNow) { $takeQty = $posNow; }
if ($tradeBid <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$inc = 0.01;
if ($tradeBid < 1) { $inc = 0.001; }
if ($tradeBid < 0.25) { $inc = 0.0005; }
$px = Round($tradeBid, 102, $inc);
// Resolve AUTOL immediately before this submission; manual routes pass through.
$routeRequest = $orderRoute;
$routeSide = "S";
$routeLimit = $px;
$routeBid = $tradeBid;
$routeAsk = $tradeAsk;
$routeUrgent = 0;
ExecHotkey("Resolve Order Route");
if ($resolvedOrderRoute == "") {
    ExecHotkey("End Trade Action");
    return;
}
$order = NewOrderObj();
$order.Account = $trade.account;
$order.Symbol = $trade.symbol;
$order.Side = "S";
$order.Type = "L";
$order.Price = $px;
$order.Share = $takeQty;
$order.Route = $resolvedOrderRoute;
$order.Tif = "DAY+";
$order.Send();
// Monitor the submitted order without holding the global action lease.
$trade.exitPending = 1;
$trade.exitStage = 1;
$trade.exitOrder = $order;
$trade.exitGeneration = $trade.generation;
$trade.exitStartPos = $posNow;
$trade.exitQty = $takeQty;
$trade.exitStarted = GetSecond();
$trade.exitTimeout = 3;
$trade.exitIsTp = 1;
$trade.exitFullFill = 0;
$trade.exitCancelWarned = 0;
$trade.entryPending = 0;
$trade.entryWatch = 0;
ExecHotkey("End Trade Action");
