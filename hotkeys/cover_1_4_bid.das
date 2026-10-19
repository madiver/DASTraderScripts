// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// =====================
// COVER 1/4 AT BID
// Group: Cover orders: Bid
// =====================
// Cancels current-symbol orders and uses DAS native Reverse for 1/4 at Bid without an offset.
// For a short position, Reverse sends a buy for the requested quantity.
// Like Cover 1/1, native Reverse also reduces a long if invoked while long.

FocusWindow Primary_OE;

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Cover 1/4 Bid aborted: Primary_OE montage unavailable.");
    ExecHotkey("End Trade Action");
    return;
}

$myAcc = StrTrim("" + $M.Account);
$mySym = StrTrim("" + $M.Symb);

if ($myAcc == "" || $mySym == "") {
    MsgBox("Cover 1/4 Bid aborted: account or symbol unavailable.");
    ExecHotkey("End Trade Action");
    return;
}
if ($orderRoute == "") {
    MsgBox("Cover 1/4 Bid aborted: orderRoute is not configured.");
    ExecHotkey("End Trade Action");
    return;
}
if (Bid <= 0) {
    MsgBox("Cover 1/4 Bid aborted: Bid is unavailable.");
    ExecHotkey("End Trade Action");
    return;
}

// Do not cancel symbol orders while flat. Native Pos supplies absolute quantity.
if (Pos <= 0) {
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
if ($symNow != $mySym || StrTrim("" + $M.Account) != $myAcc) {
    MsgBox("Cover 1/4 Bid aborted: montage account or symbol changed.");
    ExecHotkey("End Trade Action");
    return;
}
// Size from the current absolute position after cancelling older orders.
$coverPos = Pos;
if ($coverPos <= 0) {
    ExecHotkey("End Trade Action");
    return;
}
$coverQty = $coverPos * 0.25;
$coverQty = $coverQty - ($coverQty % 1);
if ($coverQty < 1) { $coverQty = 1; }
if ($coverQty > $coverPos) { $coverQty = $coverPos; }

$coverBid = Bid;
if ($coverBid <= 0) {
    MsgBox("Cover 1/4 Bid aborted: Bid is unavailable after cancelling orders.");
    ExecHotkey("End Trade Action");
    return;
}
$px = $coverBid;
if ($px <= 0) {
    MsgBox("Cover 1/4 Bid aborted: Bid is unavailable.");
    ExecHotkey("End Trade Action");
    return;
}
ROUTE=$orderRoute;
Price=$px;
// Use DAS's montage-native price rounding. Function-based Round() did not
// alter calculated prices reliably in the Open Ocean DAS build.
if ($px >= 1) { Price=Round2; }
if ($px < 1 && $px >= 0.25) { Price=Round3; }
if ($px < 0.25) { Price=Round4; }
Share=$coverQty;
TIF=DAY+;
SEND=Reverse;

MsgLog("Cover 1/4 Bid: submitted " + $coverQty + "-share Reverse for " + $mySym + " at Bid " + $px + " via " + $orderRoute + ".");

ExecHotkey("End Trade Action");
