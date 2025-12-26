// =====================
// Switch to Sim Mode
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

if  ($ACCOUNT_STATE  == "live") {

   $pos = GetWindowObj("Positions_Sim");
   $pos.AlwaysOnTop;;

   $pos = GetWindowObj("Positions_Live");
   $pos.AlwaysOnTop;

   FocusWindow Trades;
   SetFilter Account %%SIMULATED%%;
   DoFilter;

   FocusWindow Orders;
   SetFilter Account %%SIMULATED%%;
   DoFilter;

   FocusWindow Primary_OE;
   Account %%SIMULATED%%;

   FocusWindow Secondary_OE;
   Account %%SIMULATED%%;

   $ACCOUNT_STATE = "sim";

   ExecHotKey("Initialize Session Equity");

}