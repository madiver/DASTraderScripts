// =====================
// SELL 1/2 AT ASK
// Group: Sell orders: Ask
// =====================
// Cancels working orders and sends a limit sell for 1/2 of position at Ask.

FocusWindow Primary_OE;

$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) {
    return;
}

$myAcc  = $M.Account;
$mySym  = $M.Symb;
$posNow = $M.Pos;
if ($posNow <= 0) { return; }

// Compute shares to sell (half position)
$rawQty = ($posNow * 0.5);
$qty    = Round($rawQty, 102, 1);
if ($qty > $posNow) { $qty = $posNow; }
if ($qty < 1)       { $qty = $posNow; }

CXL ALLSYMB;
Wait(100);

$order = NewOrderObj();
$order.Account = $myAcc;
$order.Symbol  = $mySym;
$order.Route   = "ARCAL";
$order.Tif     = "DAY+";
$order.Side    = "S";
$order.Type    = "L";
$order.Price   = Ask;
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
