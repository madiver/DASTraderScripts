// =====================
// SWITCH TO LIVE MODE
// Group: Global controls & config
// =====================
// Switches UI filters and montage accounts to LIVE, then re-initializes session equity.

// ---- Ensure ACCOUNT_STATE is set ----
if ($ACCOUNT_STATE== "") {
    ExecHotkey("Set Global Variables");
    if ($ACCOUNT_STATE== "") {
        MsgBox("Global ACCOUNT_STATE is not set. Please check your global variable settings.");
    return;
    }
}

if ($ACCOUNT_STATE == "sim") {

   $pos = GetWindowObj("Positions_Sim");
   $pos.AlwaysOnTop;;

   $pos = GetWindowObj("Positions_Live");
   $pos.AlwaysOnTop;;

   FocusWindow Trades;
   SetFilter Account %%LIVE%%;
   DoFilter;

   FocusWindow Orders;
   SetFilter Account %%LIVE%%;
   DoFilter;

   FocusWindow Primary_OE;
   Account %%LIVE%%;

   FocusWindow Secondary_OE;
   Account %%LIVE%%;

   $ACCOUNT_STATE = "live";

   ExecHotKey("Initialize Session Equity");

}
