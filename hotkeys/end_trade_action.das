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
        SetVar("TRADE_CONTEXT_ACCOUNT", $gtfoReleaseAccount);
        SetVar("TRADE_CONTEXT_SYMBOL", $gtfoReleaseSymbol);
        ExecHotkey("GTFO");
    }
}
