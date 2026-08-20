// =====================
// SHORT TIER 1 AT ASK
// Group: Short orders: Ask
// =====================
// Sends a Tier 1 sell-short limit order at Ask.
// This manual short workflow intentionally does not arm stops or take profit.

FocusWindow Primary_OE;

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Short Tier 1 aborted: Primary_OE montage unavailable.");
    return;
}

$myAcc  = StrTrim("" + $M.Account);
$mySym  = StrTrim("" + $M.Symb);
$posNow = $M.Pos;

if ($myAcc == "" || $mySym == "") {
    MsgBox("Short Tier 1 aborted: account or symbol unavailable.");
    return;
}
if ($posNow > 0) {
    MsgBox("Short Tier 1 aborted: close the long position first.");
    return;
}
if ($orderRoute == "") {
    MsgBox("Short Tier 1 aborted: orderRoute is not configured.");
    return;
}

$rawShares = $tier1ShareSize * $qtyMult;
$roundedShares = $rawShares + 0.5;
$qty = $roundedShares - ($roundedShares % 1);
if ($qty < 1) {
    MsgBox("Short Tier 1 aborted: invalid Tier 1 share size.");
    return;
}
if (Ask <= 0) {
    MsgBox("Short Tier 1 aborted: Ask is unavailable.");
    return;
}

// Remove current-symbol orders so an older order cannot conflict with entry.
CXL ALLSYMB;
Wait(100);

// Recheck direction after the cancel delay so this hotkey cannot reverse a long.
$symNow = StrTrim("" + $M.Symb);
if ($symNow != $mySym) {
    MsgBox("Short Tier 1 aborted: montage symbol changed.");
    return;
}
$posNow = $M.Pos;
if ($posNow > 0) {
    MsgBox("Short Tier 1 aborted: position became long.");
    return;
}

$px = Ask;
if ($px <= 0) {
    MsgBox("Short Tier 1 aborted: Ask is unavailable.");
    return;
}
$inc = 0.01;
if ($px < 1)    { $inc = 0.001; }
if ($px < 0.25) { $inc = 0.0005; }
$px = Round($px, 102, $inc);

$order = NewOrderObj();
$order.Account = $myAcc;
$order.Symbol  = $mySym;
$order.Route   = $orderRoute;
$order.Tif     = "DAY+";
$order.Side    = "SS";
$order.Type    = "L";
$order.Price   = $px;
$order.Share   = $qty;
$order.Send();

MsgLog("Short Tier 1: sent " + $qty + " " + $mySym + " at Ask " + $px + " via " + $orderRoute + ".");
