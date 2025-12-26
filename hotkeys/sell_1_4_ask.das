// =====================
// Group: Sell orders: Ask
// =====================
FocusWindow Primary_OE;
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
Price=Ask;
Share=Pos*0.25;
TIF=DAY+;
SELL=Send;