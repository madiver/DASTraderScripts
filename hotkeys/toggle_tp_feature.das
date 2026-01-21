// =====================
// TOGGLE TAKE PROFIT
// Group: Utilities & toggles
// =====================
// Toggles $useTakeProfit.

if ($useTakeProfit == "Yes") {
   $useTakeProfit = "No";
   MsgLog("WARNING: take profit trigger disabled.");
} else {
   $useTakeProfit = "Yes";
   MsgLog("Take profit trigger enabled.");
}
