// =====================
// GTFO (EMERGENCY EXIT)
// Group: Global controls & config
// =====================
// Cancels all orders and sends a limit sell at Bid - 0.50 to flatten.
FocusWindow Primary_OE;
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) { return; }

$posNow = $M.Pos;
if ($posNow <= 0) { return; }

CXL ALL;
ROUTE=$orderRoute;
TIF=DAY+;
$refPx = $M.Bid;
if ($refPx <= 0) { $refPx = $M.Last; }
if ($refPx <= 0) { return; }
$inc = 0.01;
if ($refPx < 1)    { $inc = 0.001; }
if ($refPx < 0.25) { $inc = 0.0005; }
$px = $refPx - 0.50;
if ($px < $inc) { $px = $inc; }
$px = Round($px, 102, $inc);
Price=$px;
Share=$posNow;
SELL=Send;

