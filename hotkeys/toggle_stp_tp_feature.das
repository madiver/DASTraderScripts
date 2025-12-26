//=======================
// Toggle stop loss / take profit
// Group: Stops
//=======================

if ($useAutoStop == "Yes") {
   $useAutoStop = "No";
   $useTakeProfit = "No";
   MsgBox("WARNING: stop loss and take profit triggers disabled.");
} else {
   $useAutoStop = "Yes";
   $useTakeProfit = "Yes";
}