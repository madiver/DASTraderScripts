// Group: Utilities & toggles
// Internal: release one level of the cancel/fill action lease.
if (GetVar("tradeActionDepth") * 1 > 0) {
    $tradeActionDepth = $tradeActionDepth - 1;
}
// Run a queued panic as soon as the outer action ends, using its saved target.
if (GetVar("tradeActionDepth") * 1 == 0) {
    $gtfoReleaseAccount = GetVar("GTFO_PENDING_ACCOUNT");
    $gtfoReleaseSymbol = GetVar("GTFO_PENDING_SYMBOL");
    SetVar("GTFO_PENDING_ACCOUNT", "");
    SetVar("GTFO_PENDING_SYMBOL", "");
    if ($gtfoReleaseAccount != "" && $gtfoReleaseSymbol != "") {
        SetVar("EXIT_REQUEST_ACCOUNT", $gtfoReleaseAccount);
        SetVar("EXIT_REQUEST_SYMBOL", $gtfoReleaseSymbol);
        ExecHotkey("GTFO");
    }
}

if (GetVar("tradeActionDepth") * 1 == 0) { ExecHotkey("Drain Exit Requests"); }
