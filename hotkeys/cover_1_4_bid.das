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
    return;
}

$myAcc = StrTrim("" + $M.Account);
$mySym = StrTrim("" + $M.Symb);

if ($myAcc == "" || $mySym == "") {
    MsgBox("Cover 1/4 Bid aborted: account or symbol unavailable.");
    return;
}
if ($orderRoute == "") {
    MsgBox("Cover 1/4 Bid aborted: orderRoute is not configured.");
    return;
}
if (Bid <= 0) {
    MsgBox("Cover 1/4 Bid aborted: Bid is unavailable.");
    return;
}

// Do not cancel symbol orders while flat. Native Pos supplies absolute quantity.
if (Pos <= 0) { return; }

// Cancel pending entries/covers before DAS resolves the current position size.
CXL ALLSYMB;
Wait(100);

$symNow = StrTrim("" + $M.Symb);
if ($symNow != $mySym || StrTrim("" + $M.Account) != $myAcc) {
    MsgBox("Cover 1/4 Bid aborted: montage account or symbol changed.");
    return;
}
// Size from the current absolute position after cancelling older orders.
$coverPos = Pos;
if ($coverPos <= 0) { return; }
$coverQty = $coverPos * 0.25;
$coverQty = $coverQty - ($coverQty % 1);
if ($coverQty < 1) { $coverQty = 1; }
if ($coverQty > $coverPos) { $coverQty = $coverPos; }

$coverBid = Bid;
if ($coverBid <= 0) {
    MsgBox("Cover 1/4 Bid aborted: Bid is unavailable after cancelling orders.");
    return;
}
$px = $coverBid;
if ($px <= 0) {
    MsgBox("Cover 1/4 Bid aborted: Bid is unavailable.");
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
