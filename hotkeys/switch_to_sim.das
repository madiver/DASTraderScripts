// =====================
// SWITCH TO SIM MODE
// Group: Global controls & config
// =====================
// Switches UI filters and montage accounts to SIM, then re-initializes session equity.

// ---- Ensure ACCOUNT_STATE is set ----
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
