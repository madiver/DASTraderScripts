// =====================
// TOGGLE STOP LOSS
// Group: Utilities & toggles
// =====================
// Toggles $useAutoStop

if ($useAutoStop == "Yes") {
   $useAutoStop = "No";
   MsgLog("WARNING: stop loss disabled.");
} else {
   $useAutoStop = "Yes";
   MsgLog("Stop loss enabled.");
}
