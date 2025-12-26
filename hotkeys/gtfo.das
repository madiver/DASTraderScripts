// =====================
// GTFO (EMERGENCY EXIT)
// Group: Global controls & config
// =====================
// Cancels all orders and sends a limit sell at Bid - 0.50 to flatten.
CXL ALL; FocusWindow Primary_OE; ROUTE="ARCAL"; TIF=DAY+; Price=Bid-0.50; Share=Pos; SELL=Send;

