// =====================
// SELECT PRIMARY ORDER ENTRY
// Group: Utilities & toggles
// =====================
// Focuses Primary_OE and syncs Chart_1m to the current symbol.

FocusWindow Primary_OE;
$c1 = GetWindowObj("Chart_1m");
$c1.Symbol = SYMB;
