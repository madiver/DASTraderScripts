// =====================
// SELL 1/1 AT BID (OFFSET)
// Group: Sell orders: Bid-
// =====================
// Cancels working orders and sends a limit sell for 1/1 of position at Bid minus $exitOffset.

FocusWindow Primary_OE;
if (Pos <= 0) { return; }
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
// Clamp bid offset to valid tick size and positive price
$px = Bid - $exitOffset;
$inc = 0.01;
if ($px < 1 || Bid < 1)       { $inc = 0.001; }
if ($px < 0.25 || Bid < 0.25) { $inc = 0.0005; }
$px = Round($px, 102, $inc);
if ($px < $inc) { $px = $inc; }
Price=$px;
Share=Pos;
TIF=DAY+;
SELL=Send;
