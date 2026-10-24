// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// =====================
// COVER 1/1 AT ASK+
// Group: Cover orders: Ask+
// =====================
// Cancels current-symbol orders and uses DAS native Reverse at Ask plus the percentage-capped exit cushion.
// For a short position, Reverse sends a buy for Share=Pos at submission.
// Cancellation is not atomic; an older order can still fill afterward.

FocusWindow Primary_OE;

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Cover 1/1 aborted: Primary_OE montage unavailable.");
    ExecHotkey("End Trade Action");
    return;
}

$myAcc = StrTrim("" + $M.Account);
$mySym = StrTrim("" + $M.Symb);

if ($myAcc == "" || $mySym == "") {
    MsgBox("Cover 1/1 aborted: account or symbol unavailable.");
    ExecHotkey("End Trade Action");
    return;
}
if ($orderRoute == "") {
    MsgBox("Cover 1/1 aborted: orderRoute is not configured.");
    ExecHotkey("End Trade Action");
    return;
}
if (Ask <= 0) {
    MsgBox("Cover 1/1 aborted: Ask is unavailable.");
    ExecHotkey("End Trade Action");
    return;
}

// Cancel pending entries/covers before DAS resolves the current position size.
$scopedAccountObj = GetAccountObj($myAcc);
if (!IsObj($scopedAccountObj)) {
    ExecHotkey("End Trade Action");
    return;
}
$scopedAccountObj.CancelOrder("BUY|SELL", $mySym, 0);
SetVar("TRADE_CONTEXT_ACCOUNT", $myAcc);
SetVar("TRADE_CONTEXT_SYMBOL", $mySym);
ExecHotkey("Load Trade Context");
if ($tradeContextValid == 1) { ExecHotkey("Invalidate Trade Alerts"); }
Wait(100);

$symNow = StrTrim("" + $M.Symb);
if ($symNow != $mySym) {
    MsgBox("Cover 1/1 aborted: montage symbol changed.");
    ExecHotkey("End Trade Action");
    return;
}
$coverAsk = Ask;
if ($coverAsk <= 0) {
    MsgBox("Cover 1/1 aborted: Ask is unavailable after cancelling orders.");
    ExecHotkey("End Trade Action");
    return;
}
// Keep the dollar cushion, capped for low-priced ordinary exits.
$exitCushion = $exitOffset;
$exitCushionCap = $coverAsk * $exitOffsetMaxPct;
if ($exitOffsetMaxPct > 0 && $exitCushion > $exitCushionCap) { $exitCushion = $exitCushionCap; }
$px = $coverAsk + $exitCushion;
if ($px <= 0) {
    MsgBox("Cover 1/1 aborted: Ask is unavailable.");
    ExecHotkey("End Trade Action");
    return;
}

Price=$px;
// Use DAS's montage-native price rounding. Function-based Round() did not
// alter calculated prices reliably in the Open Ocean DAS build.
if ($px >= 1) { Price=Round2; }
if ($px < 1 && $px >= 0.25) { Price=Round3; }
if ($px < 0.25) { Price=Round4; }
// Preserve native DAS rounding, but keep the final limit inside the ceiling.
if ($exitOffsetMaxPct > 0 && Price > $coverAsk + $exitCushionCap) {
    $exitPriceInc = 0.01;
    if ($px < 1) { $exitPriceInc = 0.001; }
    if ($px < 0.25) { $exitPriceInc = 0.0001; }
    Price=Price-$exitPriceInc;
    if ($px >= 1) { Price=Round2; }
    if ($px < 1 && $px >= 0.25) { Price=Round3; }
    if ($px < 0.25) { Price=Round4; }
}
if (Price <= 0) {
    MsgLog("Cover aborted: no positive limit at the supported price precision.");
    ExecHotkey("End Trade Action");
    return;
}
$px = Price;
// Resolve AUTOL immediately before this submission; manual routes pass through.
$routeRequest = $orderRoute;
$routeSide = "B";
if ($posNow > 0) { $routeSide = "S"; }
$routeLimit = Price;
$routeBid = Bid;
$routeAsk = Ask;
$routeUrgent = 0;
ExecHotkey("Resolve Order Route");
if ($resolvedOrderRoute == "") {
    ExecHotkey("End Trade Action");
    return;
}
ROUTE=$resolvedOrderRoute;
Share=Pos;
TIF=DAY+;
SEND=Reverse;

MsgLog("Cover 1/1: submitted full-position Reverse for " + $mySym + " at Ask+ " + $px + " via " + $resolvedOrderRoute + ".");

ExecHotkey("End Trade Action");
