// =====================
// TOGGLE STOP LOSS
// Group: Utilities & toggles
// =====================
// Toggles $useAutoStop

if ($useAutoStop == "Yes") {
   $useAutoStop = "No";
   MsgBox("WARNING: stop loss disabled.");
} else {
   $useAutoStop = "Yes";
}
