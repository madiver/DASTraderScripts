// =====================
// SELL 1/2 AT ASK
// Group: Sell orders: Ask
// =====================
// Cancels working orders and sends a limit sell for 1/2 of position at Ask.

FocusWindow Primary_OE;
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
Price=Ask;
Share=Pos*0.5;
TIF=DAY+;
SELL=Send;
