// =====================
// SELECT PRIMARY ORDER ENTRY
// Group: Utilities & toggles
// =====================
// Focuses Primary_OE and syncs Primary_Chart to the current symbol.

FocusWindow Primary_OE;
$c1 = GetWindowObj("Primary_Chart");
if (IsObj($c1)) { $c1.Symbol = SYMB; }
