// =====================
// SWITCH TO LIVE MODE
// Group: Global controls & config
// =====================
// Switches UI filters and montage accounts to LIVE,
// then updates the AcctState chart button inline
// and re-initializes session equity.

// --- Get current account from Primary_OE ---
$M = GetWindowObj("Primary_OE");
if (!IsObj($M)) { return; }

// Force string + trim
$account = StrTrim("" + $M.Account);
if (StrLen($account) == 0) { return; }

// --- Only act if currently SIM (account starts with TR) ---
if (StrFind($account, "TR") == 0)
{
    // Bring position windows to front (if they exist)
    $pos = GetWindowObj("Positions_Sim");
    if (IsObj($pos)) { $pos.AlwaysOnTop; }

    $pos = GetWindowObj("Positions_Live");
    if (IsObj($pos)) { $pos.AlwaysOnTop; }

    // Filter Trades window to LIVE
    FocusWindow Trades;
    SetFilter Account %%LIVE%%;
    DoFilter;

    // Filter Orders window to LIVE
    FocusWindow Orders;
    SetFilter Account %%LIVE%%;
    DoFilter;

    // Switch montage(s) to LIVE account
    FocusWindow Primary_OE;
    Account %%LIVE%%;

    // --- Update AcctState chart button INLINE ---
    $btn = GetCustButObj("AcctState");
    if (IsObj($btn))
    {
        // Re-read account after switch to be explicit
        $acct2 = StrTrim("" + $M.Account);

        if (StrLen($acct2) == 0)
        {
            $btn.Text = "UNKNOWN";
            $btn.BkColor = Color("Gray");
            $btn.FgColor = Color("Black");
        }
        else if (StrFind($acct2, "TR") >= 0)
        {
            // Should not happen after LIVE switch, but defensive
            $btn.Text = "SIM";
            $btn.FgColor = Color("Black");
            $btn.BkColor = Color("Yellow");
        }
        else
        {
            $btn.Text = "LIVE";
            $btn.FgColor = Color("White");
            $btn.BkColor = Color("Blue");
        }
    }

    // Reinitialize equity/session state
    ExecHotKey("Initialize Session Equity");
}