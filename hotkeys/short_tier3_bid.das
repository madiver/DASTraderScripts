// Serialize manual actions; nested protection calls explicitly bind context.
if (GetVar("tradeActionDepth") * 1 > 0 && GetVar("TRADE_CONTEXT_ACCOUNT") == "") {
    MsgLog("Trade action already running; retry after it completes.");
    return;
}
$tradeActionDepth = GetVar("tradeActionDepth") * 1 + 1;
if ($tradeActionDepth == 1) { $tradeActionUntil = GetSecond() + 30; }
// =====================
// SHORT TIER 3 AT BID
// Group: Short orders: Bid
// =====================
// Sends a Tier 3 sell-short limit order at Bid.
// This manual short workflow intentionally does not arm stops or take profit.

FocusWindow Primary_OE;

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    MsgBox("Short Tier 3 Bid aborted: Primary_OE montage unavailable.");
    ExecHotkey("End Trade Action");
    return;
}

$myAcc  = StrTrim("" + $M.Account);
$mySym  = StrTrim("" + $M.Symb);
$posNow = $M.GetCurrPos();

if ($myAcc == "" || $mySym == "") {
    MsgBox("Short Tier 3 Bid aborted: account or symbol unavailable.");
    ExecHotkey("End Trade Action");
    return;
}

// GetCurrPos() is signed; montage .Pos is only used to detect an unresolved
// non-flat state while DAS refreshes the signed position.
$shortPosPoll = 0;
while ($posNow == 0 && $M.Pos != 0 && $shortPosPoll < 10) {
    Wait(50);
    $posNow = $M.GetCurrPos();
    $shortPosPoll = $shortPosPoll + 1;
}
if ($posNow == 0 && $M.Pos != 0) {
    MsgBox("Short Tier 3 Bid aborted: unable to resolve current position direction.");
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow > 0) {
    MsgBox("Short Tier 3 Bid aborted: close the long position first.");
    ExecHotkey("End Trade Action");
    return;
}
if ($orderRoute == "") {
    MsgBox("Short Tier 3 Bid aborted: orderRoute is not configured.");
    ExecHotkey("End Trade Action");
    return;
}

$rawShares = $tier3ShareSize * $qtyMult;
$roundedShares = $rawShares + 0.5;
$qty = $roundedShares - ($roundedShares % 1);
if ($qty < 1) {
    MsgBox("Short Tier 3 Bid aborted: invalid Tier 3 share size.");
    ExecHotkey("End Trade Action");
    return;
}
if (Bid <= 0) {
    MsgBox("Short Tier 3 Bid aborted: Bid is unavailable.");
    ExecHotkey("End Trade Action");
    return;
}

// Remove current-symbol orders so an older order cannot conflict with entry.
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

// Recheck direction after the cancel delay so this hotkey cannot reverse a long.
$symNow = StrTrim("" + $M.Symb);
if ($symNow != $mySym || StrTrim("" + $M.Account) != $myAcc) {
    MsgBox("Short Tier 3 Bid aborted: montage account or symbol changed.");
    ExecHotkey("End Trade Action");
    return;
}
$posNow = $M.GetCurrPos();
$shortPosPoll = 0;
while ($posNow == 0 && $M.Pos != 0 && $shortPosPoll < 10) {
    Wait(50);
    $posNow = $M.GetCurrPos();
    $shortPosPoll = $shortPosPoll + 1;
}
if ($posNow == 0 && $M.Pos != 0) {
    MsgBox("Short Tier 3 Bid aborted: unable to resolve position direction after cancelling orders.");
    ExecHotkey("End Trade Action");
    return;
}
if ($posNow > 0) {
    MsgBox("Short Tier 3 Bid aborted: position became long.");
    ExecHotkey("End Trade Action");
    return;
}

$px = Bid;
if ($px <= 0) {
    MsgBox("Short Tier 3 Bid aborted: Bid is unavailable.");
    ExecHotkey("End Trade Action");
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

MsgLog("Short Tier 3 Bid: sent " + $qty + " " + $mySym + " at Bid " + $px + " via " + $orderRoute + ".");

ExecHotkey("End Trade Action");
