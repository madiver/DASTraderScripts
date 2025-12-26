// =====================
// Group: Sell orders: Bid-
// =====================
FocusWindow Primary_OE;
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
Price=Bid-$exitOffset;
Share=Pos*0.25;
TIF=DAY+;
SELL=Send;