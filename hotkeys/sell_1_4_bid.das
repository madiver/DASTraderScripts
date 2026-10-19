// Group: Sell orders: Bid-
// LONG ONLY. Repeated presses reprice one tracked exit after confirmed cancellation.
FocusWindow Primary_OE;
SetVar("EXIT_REQUEST_KIND", "BID_MINUS");
SetVar("EXIT_REQUEST_DIRECTION", 1);
SetVar("EXIT_REQUEST_FRACTION", 0.25);
SetVar("EXIT_REQUEST_PRIORITY", 20);
ExecHotkey("Request Exit");
