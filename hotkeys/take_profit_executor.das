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
$order = NewOrderObj();
$order.Account = $trade.account;
$order.Symbol = $trade.symbol;
$order.Side = "S";
$order.Type = "L";
$order.Price = $px;
$order.Share = $takeQty;
$order.Route = $orderRoute;
$order.Tif = "DAY+";
$order.Send();
$tpStartPos = $posNow;
$tpPoll = 0;
while ($tpPoll < 30) {
    Wait(100);
    ExecHotkey("Read Trade Position");
    if ($tradePositionValid == 1 && $posNow <= $tpStartPos - $takeQty) { break; }
    $tpPoll = $tpPoll + 1;
}
// Cancel any residual sell before re-arming; open=0 alone can mean rejection.
$order.Cancel();
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow <= 0) { ExecHotkey("Clear Trade State"); ExecHotkey("End Trade Action"); return; }
$tpFullFill = 0;
if ($posNow <= $tpStartPos - $takeQty) { $tpFullFill = 1; }
$trade.entryLastPos = $posNow;
if ($useAutoStop == "Yes") {
    if ($tpFullFill == 1) {
        SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
        SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
        ExecHotkey("Set Auto Stop BE 1/1");
    } else {
        SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
        SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
        ExecHotkey("Set Auto Stop");
    }
}
if ($useTakeProfit == "Yes" && $tpFullFill != 1) {
    SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
    SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
    ExecHotkey("Set Take Profit");
}

ExecHotkey("End Trade Action");
