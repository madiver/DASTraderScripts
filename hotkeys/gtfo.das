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
ROUTE="ARCAL";
TIF=DAY+;
$px = $M.Bid - 0.50;
Price=$px;
Share=$posNow;
SELL=Send;

