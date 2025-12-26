// =====================
// Group: Sell orders: Ask
// =====================
FocusWindow Primary_OE;
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
Price=Ask;
Share=Pos*0.5;
TIF=DAY+;
SELL=Send;