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
$inc = 0.01;
if ($px < 1)    { $inc = 0.001; }
if ($px < 0.25) { $inc = 0.0005; }
$px = Round($px, 102, $inc);

ROUTE=$orderRoute;
Price=$px;
Share=Pos;
TIF=DAY+;
SEND=Reverse;

MsgLog("Cover 1/1: submitted full-position Reverse for " + $mySym + " at Ask+ " + $px + " via " + $orderRoute + ".");
