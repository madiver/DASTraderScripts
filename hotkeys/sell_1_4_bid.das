// =====================
// SELL 1/4 AT BID (OFFSET)
// Group: Sell orders: Bid-
// =====================
// Cancels working orders and sends a limit sell for 1/4 of position at Bid minus $exitOffset.

FocusWindow Primary_OE;

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    return;
}

$myAcc  = $M.Account;
$mySym  = $M.Symb;
$posNow = $M.Pos;
if ($posNow <= 0) { return; }

// Compute shares to sell (quarter position)
$rawQty = ($posNow * 0.25);
$qty    = Round($rawQty, 102, 1);
if ($qty > $posNow) { $qty = $posNow; }
if ($qty < 1)       { $qty = $posNow; }

CXL ALLSYMB;
Wait(100);

// Clamp bid offset to valid tick size and positive price
$px = Bid - $exitOffset;
$inc = 0.01;
if ($px < 1 || Bid < 1)       { $inc = 0.001; }
if ($px < 0.25 || Bid < 0.25) { $inc = 0.0005; }
$px = Round($px, 102, $inc);
if ($px < $inc) { $px = $inc; }

$order = NewOrderObj();
$order.Account = $myAcc;
$order.Symbol  = $mySym;
$order.Route   = "ARCAL";
$order.Tif     = "DAY+";
$order.Side    = "S";
$order.Type    = "L";
$order.Price   = $px;
$order.Share   = $qty;
$order.Send();

// Poll for full fill before re-arming stops/TP
$pollMsLocal   = $pollMs;
$maxPollsLocal = $maxPolls;
if ($pollMsLocal <= 0)   { $pollMsLocal = 100; }
if ($maxPollsLocal <= 0) { $maxPollsLocal = 20; }

$i = 0;
$filled = 0;
while ($i < $maxPollsLocal) {
    Wait($pollMsLocal);
    $order.GetInfo();
    if ($order.Open == 0) { $filled = 1; break; }
    $i = $i + 1;
}

if ($filled == 1) {
    Wait(200);
    if ($useAutoStop == "Yes") { ExecHotKey("Set Auto Stop"); }
    if ($useTakeProfit == "Yes") { ExecHotKey("Set Take Profit"); }
}
