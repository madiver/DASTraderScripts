// =====================
// SHORT TIER 2 AT ASK
// Group: Short orders: Ask
// =====================
// Sends a Tier 2 sell-short limit order at Ask.
// This manual short workflow intentionally does not arm stops or take profit.

FocusWindow Primary_OE;

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Short Tier 2 aborted: Primary_OE montage unavailable.");
    return;
}

$myAcc  = StrTrim("" + $M.Account);
$mySym  = StrTrim("" + $M.Symb);
$posNow = GetCurrPos();

if ($myAcc == "" || $mySym == "") {
    MsgBox("Short Tier 2 aborted: account or symbol unavailable.");
    return;
}

// GetCurrPos() is signed; montage .Pos is only used to detect an unresolved
// non-flat state while DAS refreshes the signed position.
$shortPosPoll = 0;
while ($posNow == 0 && $M.Pos != 0 && $shortPosPoll < 10) {
    Wait(50);
    $posNow = GetCurrPos();
    $shortPosPoll = $shortPosPoll + 1;
}
if ($posNow == 0 && $M.Pos != 0) {
    MsgBox("Short Tier 2 aborted: unable to resolve current position direction.");
    return;
}
if ($posNow > 0) {
    MsgBox("Short Tier 2 aborted: close the long position first.");
    return;
}
if ($orderRoute == "") {
    MsgBox("Short Tier 2 aborted: orderRoute is not configured.");
    return;
}

$rawShares = $tier2ShareSize * $qtyMult;
$roundedShares = $rawShares + 0.5;
$qty = $roundedShares - ($roundedShares % 1);
if ($qty < 1) {
    MsgBox("Short Tier 2 aborted: invalid Tier 2 share size.");
    return;
}
if (Ask <= 0) {
    MsgBox("Short Tier 2 aborted: Ask is unavailable.");
    return;
}

// Remove current-symbol orders so an older order cannot conflict with entry.
CXL ALLSYMB;
Wait(100);

// Recheck direction after the cancel delay so this hotkey cannot reverse a long.
$symNow = StrTrim("" + $M.Symb);
if ($symNow != $mySym) {
    MsgBox("Short Tier 2 aborted: montage symbol changed.");
    return;
}
$posNow = GetCurrPos();
$shortPosPoll = 0;
while ($posNow == 0 && $M.Pos != 0 && $shortPosPoll < 10) {
    Wait(50);
    $posNow = GetCurrPos();
    $shortPosPoll = $shortPosPoll + 1;
}
if ($posNow == 0 && $M.Pos != 0) {
    MsgBox("Short Tier 2 aborted: unable to resolve position direction after cancelling orders.");
    return;
}
if ($posNow > 0) {
    MsgBox("Short Tier 2 aborted: position became long.");
    return;
}

$px = Ask;
if ($px <= 0) {
    MsgBox("Short Tier 2 aborted: Ask is unavailable.");
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

MsgLog("Short Tier 2: sent " + $qty + " " + $mySym + " at Ask " + $px + " via " + $orderRoute + ".");
