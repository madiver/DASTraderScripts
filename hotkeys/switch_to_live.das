// =====================
// Switch to Live Mode
// Group: Global controls & config
// =====================

// ---- Use global STOPLOSS_TRIGGER if set (required) ----
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