// Group: Global controls & config
// Priority full exit. Never overlaps an unconfirmed prior exit or stop.
SetVar("EXIT_REQUEST_KIND", "EMERGENCY");
SetVar("EXIT_REQUEST_DIRECTION", 0);
SetVar("EXIT_REQUEST_FRACTION", 1);
SetVar("EXIT_REQUEST_PRIORITY", 50);
ExecHotkey("Request Exit");
