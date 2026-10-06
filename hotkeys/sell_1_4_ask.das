// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// Group: Sell orders: Ask
// LONG ONLY. Never cancels or sends an order against a short.
FocusWindow Primary_OE;
ExecHotkey("Load Trade Context");
if ($tradeContextValid != 1 || $tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
ExecHotkey("Invalidate Trade Alerts");
$trade.stopArmed = 0;
$tradeAccountObj.CancelOrder("BUY|SELL", $trade.symbol, 0);
Wait(100);
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1 || $posNow <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$qty = $posNow / 4;
$qty = $qty - ($qty % 1);
if ($qty < 1) { $qty = 1; }
if ($qty > $posNow) { $qty = $posNow; }
$px = $tradeAsk;
if ($tradeBid <= 0 || $tradeAsk <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$inc = 0.01;
if ($px < 1) { $inc = 0.001; }
if ($px < 0.25) { $inc = 0.0005; }
$px = Round($px, 102, $inc);
if ($px < $inc) { $px = $inc; }
$order = NewOrderObj();
$order.Account = $trade.account;
$order.Symbol = $trade.symbol;
$order.Route = $orderRoute;
$order.Tif = "DAY+";
$order.Side = "S";
$order.Type = "L";
$order.Price = $px;
$order.Share = $qty;
$order.Send();
// Partial exits cancel the residual before resizing long protection.
$sellPoll = 0;
$sellStartPos = $posNow;
while ($sellPoll < $maxPolls) {
    Wait($pollMs);
    ExecHotkey("Read Trade Position");
    if ($tradePositionValid == 1 && $posNow <= $sellStartPos - $qty) { break; }
    $sellPoll = $sellPoll + 1;
}
$order.Cancel();
ExecHotkey("Read Trade Position");
if ($tradePositionValid != 1) {
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow <= 0) { ExecHotkey("Clear Trade State"); ExecHotkey("End Trade Action"); return; }
$trade.entryLastPos = $posNow;
$trade.entryWatch = 1;
if ($useAutoStop == "Yes") {
    SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
    SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
    ExecHotkey("Set Auto Stop");
}
if ($useTakeProfit == "Yes") {
    SetVar("TRADE_CONTEXT_ACCOUNT", $trade.account);
    SetVar("TRADE_CONTEXT_SYMBOL", $trade.symbol);
    ExecHotkey("Set Take Profit");
}

ExecHotkey("End Trade Action");
