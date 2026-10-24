// Alerts arriving during a cancel/fill wait are queued on their own trade.
if (GetVar("tradeActionDepth") * 1 > 0) {
    $deferAcc = GetVar("TP_ACCOUNT");
    $deferSym = GetVar("TP_SYMBOL");
    $deferGen = GetVar("TP_GENERATION") * 1;
    $deferDirection = GetVar("TP_DIRECTION") * 1;
    if ($deferDirection == 0) { $deferDirection = 1; }
    $deferRevision = GetVar("TP_REVISION") * 1;
    if (IsObj(GetVar("tradeStates"))) {
        $deferTrade = $tradeStates.Get($deferAcc + "|" + $deferSym);
        if (IsObj($deferTrade)) {
            $deferCurrentRevision = 0;
            if ($deferTrade.Get("directionalTpStateVersion") == 1) { $deferCurrentRevision = $deferTrade.tpRevision; }
            if ($deferTrade.active == 1 && $deferTrade.generation == $deferGen && $deferCurrentRevision == $deferRevision) {
                $deferTrade.deferredTp = 1;
                $deferTrade.deferredTpDirection = $deferDirection;
                $deferTrade.deferredTpRevision = $deferRevision;
            }
        }
    }
    SetVar("TP_ACCOUNT", "");
    SetVar("TP_SYMBOL", "");
    SetVar("TP_GENERATION", "");
    SetVar("TP_DIRECTION", "");
    SetVar("TP_REVISION", "");
    return;
}
$tradeActionDepth = 1;
$tradeActionUntil = GetSecond() + 30;
// Group: Take profit
// Alert payload supplies account, symbol and direction, never the active montage.
$execAccount = StrTrim("" + GetVar("TP_ACCOUNT"));
$execSymbol = StrTrim("" + GetVar("TP_SYMBOL"));
$execGeneration = GetVar("TP_GENERATION") * 1;
$execDirection = GetVar("TP_DIRECTION") * 1;
if ($execDirection == 0) { $execDirection = 1; } // Legacy alerts are long-only.
$execRevision = GetVar("TP_REVISION") * 1;
SetVar("TP_ACCOUNT", "");
SetVar("TP_SYMBOL", "");
SetVar("TP_GENERATION", "");
SetVar("TP_DIRECTION", "");
SetVar("TP_REVISION", "");
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
if ($trade.generation != $execGeneration || $trade.active != 1 || $trade.tpRevision != $execRevision || $trade.tpDirection != $execDirection) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow * $execDirection <= 0) {
    $trade.tpCancelPending = 0;
    ExecHotkey("End Trade Action");
    return;
}
if ($trade.exitPending == 1) { ExecHotkey("End Trade Action"); return; }
if (($execDirection == 1 && $tradeBid <= 0) || ($execDirection == -1 && $tradeAsk <= 0)) {
    ExecHotkey("End Trade Action");
    return;
}
$tpCancelSide = "SELL";
if ($execDirection == -1) { $tpCancelSide = "BUY"; }
$tpAlert = GetAlertObj($trade.tpName);
if (IsObj($tpAlert)) { $tpAlert.Delete(); }
$trade.stopArmed = 0;
$tradeAccountObj.CancelOrder($tpCancelSide, $trade.symbol, 0);
if ($trade.tpCancelPending != 1) { Wait(300); }
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1 || $posNow * $execDirection <= 0) {
    $trade.tpCancelPending = 0;
    ExecHotkey("End Trade Action");
    return;
}
if ($execDirection == -1) {
    $tpOldShortStop = $trade.Get("shortStopOrder");
    $tpBuyPending = 0;
    if (IsObj($tpOldShortStop)) {
        $tpOldShortStop.GetInfo();
        if ($tpOldShortStop.Open != 0) { $tpBuyPending = 1; }
    }
    ExecHotkey("Check Working Buys");
    if ($tpBuyPending == 1 || $workingBuys != 0) {
        // Retry only the canceled-stop handoff, never a rejected TP order.
        $trade.tpCancelPending = 1;
        $trade.deferredTp = 1;
        $trade.deferredTpDirection = $execDirection;
        $trade.deferredTpRevision = $execRevision;
        $trade.shortWatch = 1;
        ExecHotkey("End Trade Action");
        return;
    }
    $trade.Set("shortStopOrder", 0);
}
$trade.tpCancelPending = 0;
$tpSize = $takeProfitSize;
$isLive = 0;
if (StrLen($myAcc) > 0 && StrFind($myAcc, "TR") != 0) { $isLive = 1; }
if ($rehab == 1 && ($isLive == 1 || $applyLiveGuardsToSim == 1)) { $tpSize = $takeProfitSizeRehab; }
$tpPositionSize = $posNow * $execDirection;
$takeQty = $tpPositionSize * $tpSize;
$takeQty = $takeQty - ($takeQty % 1);
if ($takeQty < 1) { $takeQty = 1; }
if ($takeQty > $tpPositionSize) { $takeQty = $tpPositionSize; }
$tpQuote = $tradeBid;
$tpSide = "S";
if ($execDirection == -1) { $tpQuote = $tradeAsk; $tpSide = "B"; }
if ($tpQuote <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$inc = 0.01;
if ($tpQuote < 1) { $inc = 0.001; }
if ($tpQuote < 0.25) { $inc = 0.0005; }
$px = Round($tpQuote, 102, $inc);
if ($px <= 0) { ExecHotkey("End Trade Action"); return; }
// Resolve AUTOL immediately before this submission; manual routes pass through.
$routeRequest = $orderRoute;
$routeSide = $tpSide;
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
$order.Side = $tpSide;
$order.Type = "L";
$order.Price = $px;
$order.Share = $takeQty;
$order.Route = $resolvedOrderRoute;
$order.Tif = "DAY+";
$order.Send();
// Consume this alert revision so a captured payload cannot execute twice.
$trade.tpRevision = $trade.tpRevision + 1;
$trade.deferredTp = 0;
$trade.tpName = "";
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
