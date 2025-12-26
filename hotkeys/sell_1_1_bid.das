// =====================
// Group: Sell orders: Bid-
// =====================
FocusWindow Primary_OE;
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
Price=Bid-$exitOffset;
Share=Pos;
TIF=DAY+;
SELL=Send;