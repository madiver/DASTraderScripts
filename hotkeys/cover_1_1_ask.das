// =====================
// COVER 1/1 AT ASK+
// Group: Cover orders: Ask+
// =====================
// Cancels current-symbol orders and uses DAS native Reverse at Ask + exitOffset.
// For a short position, Reverse sends a buy for Share=Pos and cannot add past flat.

FocusWindow Primary_OE;

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Cover 1/1 aborted: Primary_OE montage unavailable.");
    return;
}

$myAcc = StrTrim("" + $M.Account);
$mySym = StrTrim("" + $M.Symb);

if ($myAcc == "" || $mySym == "") {
    MsgBox("Cover 1/1 aborted: account or symbol unavailable.");
    return;
}
if ($orderRoute == "") {
    MsgBox("Cover 1/1 aborted: orderRoute is not configured.");
    return;
}
if (Ask <= 0) {
    MsgBox("Cover 1/1 aborted: Ask is unavailable.");
    return;
}

// Cancel pending entries/covers before DAS resolves the current position size.
CXL ALLSYMB;
Wait(100);

$symNow = StrTrim("" + $M.Symb);
if ($symNow != $mySym) {
    MsgBox("Cover 1/1 aborted: montage symbol changed.");
    return;
}
$px = Ask + $exitOffset;
if ($px <= 0) {
    MsgBox("Cover 1/1 aborted: Ask is unavailable.");
    return;
}
ROUTE=$orderRoute;
Price=$px;
// Use DAS's montage-native price rounding. Function-based Round() did not
// alter calculated prices reliably in the Open Ocean DAS build.
if ($px >= 1) { Price=Round2; }
if ($px < 1)  { Price=Round3; }
if ($px < 0.25) { Price=Round4; }
Share=Pos;
TIF=DAY+;
SEND=Reverse;

MsgLog("Cover 1/1: submitted full-position Reverse for " + $mySym + " at Ask+ " + $px + " via " + $orderRoute + ".");
