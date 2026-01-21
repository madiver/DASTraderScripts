// =====================
// TOGGLE DYNAMIC STOP
// Group: Utilities & toggles
// =====================
// Toggles $dynamicStop (buy_ib only).
if ($dynamicStop == 1) {
   $dynamicStop = 0;
   $stopMode = "STANDARD";
   $structuredOk = 0;
   $structuredReason = 0;
   $structuredType = "";
   $structuredStop = 0;
   $structuredR = 0;
   $structuredSymbol = "";
} else {
   $dynamicStop = 1;
   $stopMode = "DYNAMIC";
   $structuredOk = 0;
   $structuredReason = 0;
   $structuredType = "";
   $structuredStop = 0;
   $structuredR = 0;
   $structuredSymbol = "";
   MsgBox("WARNING: dynamic stops enabled (buy_ib only).");
}
