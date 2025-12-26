// =====================
// SELL 1/1 AT ASK
// Group: Sell orders: Ask
// =====================
// Cancels working orders and sends a limit sell for 1/1 of position at Ask.

FocusWindow Primary_OE;
CXL ALLSYMB;
Wait(100);
ROUTE="ARCAL";
Price=Ask;
Share=Pos;
TIF=DAY+;
SELL=Send;
