// =====================
// Group: Sell orders: Ask
// =====================
FocusWindow Primary_OE;
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
Price=Ask;
Share=Pos;
TIF=DAY+;
SELL=Send;