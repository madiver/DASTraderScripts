// =====================
// TOGGLE DYNAMIC STOP
// Group: Utilities & toggles
// =====================
// Toggles $dynamicStop (buy_ib only).
if ($dynamicStop == 1) {
   $dynamicStop = 0;
   $stopMode = "STANDARD";
} else {
   $dynamicStop = 1;
   $stopMode = "DYNAMIC";
   MsgBox("WARNING: dynamic stops enabled (buy_ib only).");
}
