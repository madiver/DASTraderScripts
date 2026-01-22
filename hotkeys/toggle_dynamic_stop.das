// =====================
// TOGGLE DYNAMIC STOP
// Group: Utilities & toggles
// =====================
// Toggles $dynamicStop (buy_ib only).
if ($dynamicStop == 1) {
   $dynamicStop = 0;
   $stopMode = "FIXED";
   $structuredOk = 0;
   $structuredReason = 0;
   $structuredType = "";
   $structuredStop = 0;
   $structuredR = 0;
   $structuredSymbol = "";
   MsgLog("Dynamic stop mode disabled.");
} else {
   $dynamicStop = 1;
   $stopMode = "DYNAMIC";
   $structuredOk = 0;
   $structuredReason = 0;
   $structuredType = "";
   $structuredStop = 0;
   $structuredR = 0;
   $structuredSymbol = "";
   MsgLog("Dynamic stop mode enabled (IB only).");
}
