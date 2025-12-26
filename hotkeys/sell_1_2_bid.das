// =====================
// SELL 1/2 AT BID (OFFSET)
// Group: Sell orders: Bid-
// =====================
// Cancels working orders and sends a limit sell for 1/2 of position at Bid minus $exitOffset.

FocusWindow Primary_OE;
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
Price=Bid-$exitOffset;
Share=Pos*0.5;
TIF=DAY+;
SELL=Send;
