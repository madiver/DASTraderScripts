// =====================
// TOGGLE TAKE PROFIT
// Group: Utilities & toggles
// =====================
// Toggles $useTakeProfit.

if ($useTakeProfit == "Yes") {
   $useTakeProfit = "No";
   MsgBox("WARNING: take profit trigger disabled.");
} else {
   $useTakeProfit = "Yes";
}
