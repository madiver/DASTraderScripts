// Group: Global controls & config
// Cancel safely; retain order tracking until the acknowledgment arrives.
SetVar("EXIT_REQUEST_KIND", "CANCEL");
SetVar("EXIT_REQUEST_DIRECTION", 0);
SetVar("EXIT_REQUEST_FRACTION", 1);
SetVar("EXIT_REQUEST_PRIORITY", 60);
ExecHotkey("Request Exit");
