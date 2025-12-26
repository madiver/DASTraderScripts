// =====================
// TOGGLE STOP LOSS / TAKE PROFIT
// Group: Stops
// =====================
// Toggles $useAutoStop and $useTakeProfit.

if ($useAutoStop == "Yes") {
   $useAutoStop = "No";
   $useTakeProfit = "No";
   MsgBox("WARNING: stop loss and take profit triggers disabled.");
} else {
   $useAutoStop = "Yes";
   $useTakeProfit = "Yes";
}
